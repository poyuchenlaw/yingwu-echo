package main

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
	"github.com/redis/go-redis/v9"

	"github.com/simonchen/yingwu-echo/backend/internal/analyzer"
	"github.com/simonchen/yingwu-echo/backend/internal/api"
)

// demoStore holds inline analyze results keyed by writing_id for stub mode (no DB).
type demoEntry struct {
	Status            string  `json:"status"`
	WuxingDetected    string  `json:"wuxing_detected"`
	CelestialDetected string  `json:"celestial_detected"`
	MonsterName       string  `json:"monster_name"`
	CardQuote         string  `json:"card_quote"`
	ValidityScore     float64 `json:"validity_score"`
	UsedFallback      bool    `json:"used_fallback"`
}

var (
	demoMu    sync.RWMutex
	demoStore = map[string]demoEntry{}
	demoLLM   analyzer.LLMClient
)

func main() {
	port := getenv("PORT", "8080")
	dbURL := os.Getenv("DATABASE_URL")
	redisURL := getenv("REDIS_URL", "redis://localhost:6379/0")
	geminiKey := os.Getenv("GEMINI_API_KEY")

	db := openDB(dbURL)
	if db != nil {
		defer db.Close()
	}
	rdb := openRedis(redisURL)
	worker, llm := startAnalyzerWorker(rdb, geminiKey)
	demoLLM = llm

	handler := api.NewHandler(db, rdb)
	if db != nil {
		handler.SetAnalyzer(func(ctx context.Context, writingID, content, emotionTag string) {
			if demoLLM == nil {
				log.Printf("analyzer-cb: no LLM, marking %s FAILED", writingID)
				_ = handler.MarkWritingFailed(ctx, writingID, "no_llm")
				return
			}
			res, err := demoLLM.Analyze(ctx, analyzer.AnalysisRequest{
				WritingID: writingID, Content: content, EmotionTag: emotionTag,
			})
			if err != nil {
				log.Printf("analyzer-cb: LLM error for %s: %v — falling back to heuristic", writingID, err)
				fb := analyzer.FallbackAnalyze(emotionTag)
				// Heuristic returns CN celestial like 海王 — translate to 海王星
				cel := fb.CelestialDetected
				if cel == "海王" { cel = "海王星" }
				if cel == "天王" { cel = "天王星" }
				if uerr := handler.UpdateWritingAnalysis(ctx, writingID, fb.WuxingDetected, cel, "未知共鳴體", "（fallback：靜待 AI 重連）", 0.5); uerr != nil {
					log.Printf("analyzer-cb: fallback update failed: %v", uerr)
				}
				return
			}
			if uerr := handler.UpdateWritingAnalysis(ctx, writingID, res.WuxingDetected, res.CelestialDetected, res.MonsterName, res.CardQuote, res.ValidityScore); uerr != nil {
				log.Printf("analyzer-cb: update %s failed: %v", writingID, uerr)
			}
			wuxingEN := api.WuxingCNtoEN[res.WuxingDetected]
			if wuxingEN == "" {
				wuxingEN = "earth"
			}
			if mid, merr := handler.AcquireMonsterForWriting(ctx, api.DefaultPlayerID, emotionTag, wuxingEN, res.MonsterName); merr != nil {
				log.Printf("analyzer-cb: acquire monster failed for %s: %v", writingID, merr)
			} else if mid != "" {
				log.Printf("analyzer-cb: acquired monster %s for writing %s", mid, writingID)
			}
		})
		log.Printf("analyzer callback wired to handler (db-mode)")
	}
	r := gin.Default()
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "yingwu-echo"})
	})
	api.RegisterRoutes(r, handler)
	demo := r.Group("/api/v1/demo")
	{
		demo.POST("/analyze", demoAnalyze)
		demo.GET("/result/:id", demoResult)
	}
	r.StaticFile("/", "./web/demo.html")
	r.StaticFile("/demo", "./web/demo.html")

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		log.Printf("yingwu-echo server listening on :%s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server failed: %v", err)
		}
	}()

	<-stop
	log.Printf("shutdown signal received")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("server shutdown: %v", err)
	}
	if worker != nil {
		worker.Stop()
		log.Printf("analyzer worker stopped")
	}
}

func demoAnalyze(c *gin.Context) {
	var req struct {
		Content    string `json:"content" binding:"required"`
		EmotionTag string `json:"emotion_tag" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	id := time.Now().UTC().Format("20060102T150405.000")
	if demoLLM == nil {
		demoLLM = &analyzer.MockLLMClient{}
	}
	ctx, cancel := context.WithTimeout(c.Request.Context(), 60*time.Second)
	defer cancel()
	result, err := demoLLM.Analyze(ctx, analyzer.AnalysisRequest{
		WritingID:  id,
		Content:    req.Content,
		EmotionTag: req.EmotionTag,
	})
	usedFallback := false
	var llmErr string
	if err != nil {
		llmErr = err.Error()
		log.Printf("demoAnalyze llm error: %v", err)
		fb := analyzer.FallbackAnalyze(req.EmotionTag)
		result = analyzer.AnalysisResult{
			WuxingDetected:    fb.WuxingDetected,
			CelestialDetected: fb.CelestialDetected,
		}
		usedFallback = true
	}
	entry := demoEntry{
		Status:            "COMPLETE",
		WuxingDetected:    result.WuxingDetected,
		CelestialDetected: result.CelestialDetected,
		MonsterName:       result.MonsterName,
		CardQuote:         result.CardQuote,
		ValidityScore:     result.ValidityScore,
		UsedFallback:      usedFallback,
	}
	demoMu.Lock()
	demoStore[id] = entry
	demoMu.Unlock()
	resp := gin.H{"writing_id": id, "analysis": entry}
	if llmErr != "" {
		resp["llm_error"] = llmErr
	}
	c.JSON(http.StatusOK, resp)
}

func demoResult(c *gin.Context) {
	id := c.Param("id")
	demoMu.RLock()
	entry, ok := demoStore[id]
	demoMu.RUnlock()
	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
		return
	}
	c.JSON(http.StatusOK, entry)
}

func openDB(dbURL string) *sql.DB {
	if dbURL == "" {
		log.Printf("DATABASE_URL not set — handler runs in stub mode")
		return nil
	}
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("sql.Open: %v", err)
	}
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		log.Fatalf("db ping: %v", err)
	}
	log.Printf("db connected")
	return db
}

func openRedis(redisURL string) *redis.Client {
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Printf("redis.ParseURL failed (%v) — continuing without queue", err)
		return nil
	}
	rdb := redis.NewClient(opt)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Printf("redis ping failed (%v) — continuing without queue", err)
		return nil
	}
	log.Printf("redis connected")
	return rdb
}

func startAnalyzerWorker(rdb *redis.Client, geminiKey string) (*analyzer.Worker, analyzer.LLMClient) {
	var llm analyzer.LLMClient
	if geminiKey != "" {
		gc, err := analyzer.NewGeminiClient(geminiKey, "", 45*time.Second)
		if err != nil {
			log.Printf("gemini client init failed (%v) — falling back to mock", err)
			llm = &analyzer.MockLLMClient{}
		} else {
			llm = gc
			log.Printf("analyzer using Gemini client")
		}
	} else {
		log.Printf("GEMINI_API_KEY not set — analyzer using MockLLMClient")
		llm = &analyzer.MockLLMClient{}
	}
	if rdb == nil {
		return nil, llm
	}
	w := analyzer.NewWorker(rdb, llm, nil)
	w.Start()
	log.Printf("analyzer worker started (pool=%d)", analyzer.WorkerCount)
	return w, llm
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
