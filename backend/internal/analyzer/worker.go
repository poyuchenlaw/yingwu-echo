package analyzer

import (
	"context"
	"encoding/json"
	"log"
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
	Content    string `json:"content"`
	EmotionTag string `json:"emotion_tag"`
}

// ForgeHook is called after analysis to trigger card-draw logic in the forge package.
// TODO: wire to forge.TriggerDraw once forge package exposes that entry point.
type ForgeHook func(writingID string, wuxing string, celestial string)

// Worker manages a pool of goroutines that consume from the Redis analysis queue.
type Worker struct {
	redis  *redis.Client
	client LLMClient
	hook   ForgeHook
	stopCh chan struct{}
	wg     sync.WaitGroup
}

// NewWorker creates a Worker. redisClient and llm must not be nil.
func NewWorker(redisClient *redis.Client, llm LLMClient, hook ForgeHook) *Worker {
	return &Worker{
		redis:  redisClient,
		client: llm,
		hook:   hook,
		stopCh: make(chan struct{}),
	}
}

// Start launches WorkerCount goroutines.
func (w *Worker) Start() {
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
			analyzeCtx, analyzeCancel := context.WithTimeout(context.Background(), 25*time.Second)
			result, usedFallback, _ := RetryWithFallback(analyzeCtx, w.client, AnalysisRequest{
				WritingID:  task.WritingID,
				Content:    task.Content,
				EmotionTag: task.EmotionTag,
			})
			analyzeCancel()
			log.Printf("analyzer worker: id=%s wuxing=%s celestial=%s fallback=%v",
				task.WritingID, result.WuxingDetected, result.CelestialDetected, usedFallback)
			// TODO: UPDATE player_writings SET wuxing_detected=$1, celestial_detected=$2, status='ANALYZED' WHERE id=$3
			if w.hook != nil {
				w.hook(task.WritingID, result.WuxingDetected, result.CelestialDetected)
			}
		}
	}
}
