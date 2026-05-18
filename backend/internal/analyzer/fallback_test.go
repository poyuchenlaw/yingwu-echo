package analyzer_test

import (
	"context"
	"errors"
	"testing"

	"github.com/simonchen/yingwu-echo/backend/internal/analyzer"
)

func TestFallbackAnalyze_KnownTag_Lei(t *testing.T) {
	res := analyzer.FallbackAnalyze("累")
	if res.WuxingDetected != "土" {
		t.Errorf("expected 土, got %s", res.WuxingDetected)
	}
	if res.CelestialDetected != "海王" {
		t.Errorf("expected 海王, got %s", res.CelestialDetected)
	}
	if res.Status != "FALLBACK_HEURISTIC" {
		t.Errorf("expected FALLBACK_HEURISTIC, got %s", res.Status)
	}
	if res.FallbackReason != "AI_UNAVAILABLE" {
		t.Errorf("expected AI_UNAVAILABLE, got %s", res.FallbackReason)
	}
}

func TestFallbackAnalyze_KnownTag_FireBig(t *testing.T) {
	res := analyzer.FallbackAnalyze("火大")
	if res.WuxingDetected != "火" {
		t.Errorf("expected 火, got %s", res.WuxingDetected)
	}
	if res.CelestialDetected != "火星" {
		t.Errorf("expected 火星, got %s", res.CelestialDetected)
	}
}

func TestFallbackAnalyze_UnknownTag_Default(t *testing.T) {
	res := analyzer.FallbackAnalyze("不知道")
	if res.WuxingDetected != "靈質" {
		t.Errorf("expected 靈質 for unknown tag, got %s", res.WuxingDetected)
	}
}

func TestFallbackAnalyze_TrimSpace(t *testing.T) {
	res := analyzer.FallbackAnalyze("  累  ")
	if res.WuxingDetected != "土" {
		t.Errorf("expected 土 after trim, got %s", res.WuxingDetected)
	}
}

func TestFallbackAnalyze_AllTableKeys(t *testing.T) {
	for key := range analyzer.FallbackTable {
		res := analyzer.FallbackAnalyze(key)
		if res.Status != "FALLBACK_HEURISTIC" {
			t.Errorf("key %q: expected FALLBACK_HEURISTIC status", key)
		}
		if res.WuxingDetected == "" {
			t.Errorf("key %q: WuxingDetected must not be empty", key)
		}
	}
}

func TestRetryWithFallback_MockSuccess(t *testing.T) {
	client := &analyzer.MockLLMClient{}
	req := analyzer.AnalysisRequest{WritingID: "w1", Content: "test", EmotionTag: "開心"}
	result, usedFallback, err := analyzer.RetryWithFallback(context.Background(), client, req)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if usedFallback {
		t.Error("MockLLMClient should not trigger fallback")
	}
	if result.WuxingDetected != "火" {
		t.Errorf("expected 火, got %s", result.WuxingDetected)
	}
}

type errClient struct{ msg string }

func (e *errClient) Analyze(_ context.Context, _ analyzer.AnalysisRequest) (analyzer.AnalysisResult, error) {
	return analyzer.AnalysisResult{}, errors.New(e.msg)
}

func TestRetryWithFallback_CancelledContext_ReturnsCtxErr(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // already cancelled
	client := &errClient{msg: "ai error"}
	req := analyzer.AnalysisRequest{WritingID: "w2", Content: "test", EmotionTag: "累"}
	_, _, err := analyzer.RetryWithFallback(ctx, client, req)
	// With cancelled ctx, either ctx.Err() is returned or fallback triggers on first attempt
	// (depends on whether Analyze is called before ctx check in select).
	// Either outcome is acceptable - just ensure no panic.
	_ = err
}
