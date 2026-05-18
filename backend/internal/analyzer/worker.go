package analyzer

import (
	"context"
	"encoding/json"
	"log"
	"fmt"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

// WorkerCount is the size of the goroutine pool.
const WorkerCount = 5

// RedisQueueKey is the Redis list key used as the analysis task queue.
const RedisQueueKey = "writing_analysis_queue"

// WritingTask is the payload pushed to the Redis queue by the HTTP handler.
type WritingTask struct {
	WritingID  string `json:"writing_id"`
	PlayerID   string `json:"player_id"`
	Content    string `json:"content"`
	EmotionTag string `json:"emotion_tag"`
}

// PersistFn persists analysis results back to the database.
type PersistFn func(ctx context.Context, writingID, wuxingCN, celestial, monsterName, cardQuote string, validity float64) error

// AcquireFn assigns a monster to the player after analysis.
type AcquireFn func(ctx context.Context, playerID, emotionTag, wuxingCN, monsterName string) (string, error)

// ForgeHook is called after analysis to trigger card-draw logic in the forge package.
// TODO: wire to forge.TriggerDraw once forge package exposes that entry point.
type ForgeHook func(writingID string, wuxing string, celestial string)

// Worker manages a pool of goroutines that consume from the Redis analysis queue.
type Worker struct {
	redis     *redis.Client
	client    LLMClient
	hook      ForgeHook
	persist   PersistFn
	acquire   AcquireFn
	OnFailure func(kind, severity, target, errMsg string, ctx map[string]any)
	stopCh    chan struct{}
	wg        sync.WaitGroup
}

// NewWorker creates a Worker. redisClient and llm must not be nil.
// persist and acquire may be nil (worker operates in reduced-capability mode).
func NewWorker(redisClient *redis.Client, llm LLMClient, hook ForgeHook, persist PersistFn, acquire AcquireFn, onFailure func(kind, severity, target, errMsg string, ctx map[string]any)) *Worker {
	return &Worker{
		redis:     redisClient,
		client:    llm,
		hook:      hook,
		persist:   persist,
		acquire:   acquire,
		OnFailure: onFailure,
		stopCh:    make(chan struct{}),
	}
}

// Start launches WorkerCount goroutines.
func (w *Worker) Start() {
	mode := "inert"
	if w.persist != nil && w.acquire != nil {
		mode = "persist+acquire"
	} else if w.persist != nil {
		mode = "persist"
	}
	log.Printf("analyzer.Worker.Start: pool=%d mode=%s", WorkerCount, mode)
	for i := 0; i < WorkerCount; i++ {
		w.wg.Add(1)
		go w.loop()
	}
}

// Stop signals all goroutines to exit and waits for them.
func (w *Worker) Stop() {
	close(w.stopCh)
	w.wg.Wait()
}

func (w *Worker) reportFailure(kind, severity, target, errMsg string, ctx map[string]any) {
	if w.OnFailure != nil {
		w.OnFailure(kind, severity, target, errMsg, ctx)
	}
}

func (w *Worker) processTask(task WritingTask) {
	defer func() {
		if r := recover(); r != nil {
			w.reportFailure("goroutine_panic", "P0", task.WritingID, fmt.Sprintf("%v", r), nil)
		}
	}()
	analyzeCtx, analyzeCancel := context.WithTimeout(context.Background(), 25*time.Second)
	result, usedFallback, _ := RetryWithFallback(analyzeCtx, w.client, AnalysisRequest{
		WritingID:  task.WritingID,
		Content:    task.Content,
		EmotionTag: task.EmotionTag,
	})
	analyzeCancel()
	log.Printf("analyzer worker: id=%s wuxing=%s celestial=%s fallback=%v",
		task.WritingID, result.WuxingDetected, result.CelestialDetected, usedFallback)
	if w.persist != nil {
		persistCtx, persistCancel := context.WithTimeout(context.Background(), 10*time.Second)
		if err := w.persist(persistCtx, task.WritingID, result.WuxingDetected, result.CelestialDetected, result.MonsterName, result.CardQuote, result.ValidityScore); err != nil {
			log.Printf("analyzer worker: persist error for %s: %v", task.WritingID, err)
			w.reportFailure("persist_failure", "P0", task.WritingID, err.Error(), map[string]any{"player_id": task.PlayerID})
		}
		persistCancel()
	}
	if w.acquire != nil && task.PlayerID != "" {
		acquireCtx, acquireCancel := context.WithTimeout(context.Background(), 10*time.Second)
		mid, err := w.acquire(acquireCtx, task.PlayerID, task.EmotionTag, result.WuxingDetected, result.MonsterName)
		if err != nil {
			log.Printf("analyzer worker: acquire error for %s: %v", task.WritingID, err)
			w.reportFailure("acquire_failure", "P0", task.WritingID, err.Error(), map[string]any{"player_id": task.PlayerID})
		} else if mid != "" {
			log.Printf("analyzer worker: acquired monster %s for writing %s", mid, task.WritingID)
		}
		acquireCancel()
	}
	if w.hook != nil {
		w.hook(task.WritingID, result.WuxingDetected, result.CelestialDetected)
	}
}

func (w *Worker) loop() {
	defer w.wg.Done()
	for {
		select {
		case <-w.stopCh:
			return
		default:
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			vals, err := w.redis.BLPop(ctx, 2*time.Second, RedisQueueKey).Result()
			cancel()
			if err != nil {
				continue
			}
			if len(vals) < 2 {
				continue
			}
			var task WritingTask
			if err := json.Unmarshal([]byte(vals[1]), &task); err != nil {
				log.Printf("analyzer worker: unmarshal error: %v", err)
				continue
			}
			w.processTask(task)
		}
	}
}
