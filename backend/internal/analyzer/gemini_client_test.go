package analyzer_test

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
	_ "unsafe"

	"github.com/simonchen/yingwu-echo/backend/internal/analyzer"
)

//go:linkname geminiAPIBase github.com/simonchen/yingwu-echo/backend/internal/analyzer.geminiAPIBase
var geminiAPIBase string

const validAnalysisText = `{"wuxing":"火","celestial":"火星","monster_name":"赤鬃","card_quote":"火光在胸腔裡沿著肋骨慢慢繞了一圈又一圈","validity_score":0.85}`

func Test_NewGeminiClient_EmptyKey_ReturnsError(t *testing.T) {
	client, err := analyzer.NewGeminiClient("", "", 0)
	if err == nil {
		t.Fatal("expected error for empty api key")
	}
	if client != nil {
		t.Fatal("expected nil client for empty api key")
	}
}

func Test_NewGeminiClient_DefaultsApplied(t *testing.T) {
	client, err := analyzer.NewGeminiClient("key", "", 0)
	if err != nil {
		t.Fatalf("expected constructor success: %v", err)
	}
	if client == nil {
		t.Fatal("expected non-nil client")
	}
}

func Test_GeminiClient_Analyze_Success(t *testing.T) {
	var hits int32
	withGeminiServer(t, func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
		writeEnvelope(t, w, validAnalysisText)
	})
	client := newTestClient(t)

	got, err := client.Analyze(context.Background(), analyzer.AnalysisRequest{
		Content:    "今天通勤很悶，但我還是想把心裡的火寫下來。",
		EmotionTag: "火大",
	})
	if err != nil {
		t.Fatalf("Analyze returned error: %v", err)
	}
	if got.WuxingDetected != "火" ||
		got.CelestialDetected != "火星" ||
		got.MonsterName != "赤鬃" ||
		got.CardQuote != "火光在胸腔裡沿著肋骨慢慢繞了一圈又一圈" {
		t.Fatalf("unexpected result: %#v", got)
	}
	if atomic.LoadInt32(&hits) != 1 {
		t.Fatalf("expected 1 hit, got %d", hits)
	}
}

func Test_GeminiClient_Analyze_InvalidJSON_ReturnsError(t *testing.T) {
	var hits int32
	withGeminiServer(t, func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
		writeEnvelope(t, w, "not json")
	})
	client := newTestClient(t)

	_, err := client.Analyze(context.Background(), analyzer.AnalysisRequest{
		Content:    "test",
		EmotionTag: "火大",
	})
	if err == nil {
		t.Fatal("expected parse error")
	}
	if atomic.LoadInt32(&hits) != 1 {
		t.Fatalf("expected no retry, got %d hits", hits)
	}
}

func Test_GeminiClient_Analyze_429_RetriesThenFails(t *testing.T) {
	var hits int32
	withGeminiServer(t, func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
		http.Error(w, "rate limited", http.StatusTooManyRequests)
	})
	client := newTestClient(t)

	_, err := client.Analyze(context.Background(), analyzer.AnalysisRequest{
		Content:    "test",
		EmotionTag: "火大",
	})
	if err == nil || !strings.Contains(err.Error(), "exhausted") {
		t.Fatalf("expected exhausted error, got %v", err)
	}
	if atomic.LoadInt32(&hits) != 3 {
		t.Fatalf("expected 3 hits, got %d", hits)
	}
}

func Test_GeminiClient_Analyze_500_RetriesThenFails(t *testing.T) {
	var hits int32
	withGeminiServer(t, func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
		http.Error(w, "server error", http.StatusInternalServerError)
	})
	client := newTestClient(t)

	_, err := client.Analyze(context.Background(), analyzer.AnalysisRequest{
		Content:    "test",
		EmotionTag: "火大",
	})
	if err == nil || !strings.Contains(err.Error(), "exhausted") {
		t.Fatalf("expected exhausted error, got %v", err)
	}
	if atomic.LoadInt32(&hits) != 3 {
		t.Fatalf("expected 3 hits, got %d", hits)
	}
}

func Test_GeminiClient_Analyze_400_FailsFast(t *testing.T) {
	var hits int32
	withGeminiServer(t, func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
		http.Error(w, "bad request", http.StatusBadRequest)
	})
	client := newTestClient(t)

	_, err := client.Analyze(context.Background(), analyzer.AnalysisRequest{
		Content:    "test",
		EmotionTag: "火大",
	})
	if err == nil {
		t.Fatal("expected error")
	}
	if strings.Contains(err.Error(), "exhausted") {
		t.Fatalf("expected fail-fast error, got %v", err)
	}
	if atomic.LoadInt32(&hits) != 1 {
		t.Fatalf("expected 1 hit, got %d", hits)
	}
}

func Test_GeminiClient_Analyze_ContextCancelled(t *testing.T) {
	withGeminiServer(t, func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(time.Second)
		writeEnvelope(t, w, validAnalysisText)
	})
	client := newTestClient(t)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := client.Analyze(ctx, analyzer.AnalysisRequest{
		Content:    "test",
		EmotionTag: "火大",
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected context canceled, got %v", err)
	}
}

func Test_GeminiClient_Analyze_429ThenSuccess(t *testing.T) {
	var hits int32
	withGeminiServer(t, func(w http.ResponseWriter, r *http.Request) {
		if atomic.AddInt32(&hits, 1) == 1 {
			http.Error(w, "rate limited", http.StatusTooManyRequests)
			return
		}
		writeEnvelope(t, w, validAnalysisText)
	})
	client := newTestClient(t)

	got, err := client.Analyze(context.Background(), analyzer.AnalysisRequest{
		Content:    "test",
		EmotionTag: "火大",
	})
	if err != nil {
		t.Fatalf("Analyze returned error: %v", err)
	}
	if got.WuxingDetected != "火" || got.CelestialDetected != "火星" {
		t.Fatalf("unexpected result: %#v", got)
	}
	if atomic.LoadInt32(&hits) != 2 {
		t.Fatalf("expected 2 hits, got %d", hits)
	}
}

func withGeminiServer(t *testing.T, handler http.HandlerFunc) {
	t.Helper()
	defer func() {
		if r := recover(); r != nil {
			msg := fmt.Sprint(r)
			if strings.Contains(msg, "httptest: failed to listen") {
				t.Skipf("httptest server unavailable in this environment: %v", r)
			}
			panic(r)
		}
	}()
	server := httptest.NewServer(handler)
	oldBase := geminiAPIBase
	geminiAPIBase = server.URL
	t.Cleanup(func() {
		geminiAPIBase = oldBase
		server.Close()
	})
}

func newTestClient(t *testing.T) *analyzer.GeminiClient {
	t.Helper()
	client, err := analyzer.NewGeminiClient("test-key", "test-model", 2*time.Second)
	if err != nil {
		t.Fatalf("NewGeminiClient returned error: %v", err)
	}
	return client
}

func writeEnvelope(t *testing.T, w http.ResponseWriter, text string) {
	t.Helper()
	w.Header().Set("Content-Type", "application/json")
	err := json.NewEncoder(w).Encode(map[string]any{
		"candidates": []map[string]any{{
			"content": map[string]any{
				"parts": []map[string]string{{"text": text}},
			},
		}},
	})
	if err != nil {
		t.Fatalf("write envelope: %v", err)
	}
}
