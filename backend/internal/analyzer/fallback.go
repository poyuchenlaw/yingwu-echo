package analyzer

import (
	"context"
	"strings"
	"time"
)

// Element is a wuxing + celestial pair for heuristic mapping.
type Element struct {
	Wuxing    string
	Celestial string
}

// FallbackResult is the output of the heuristic fallback path.
type FallbackResult struct {
	WuxingDetected    string
	CelestialDetected string
	Status            string
	FallbackReason    string
}

const (
	fallbackStatus = "FALLBACK_HEURISTIC"
	fallbackReason = "AI_UNAVAILABLE"
)

// FallbackTable maps emotion tags to wuxing + celestial pairs.
// Exported so tests can iterate all keys.
var FallbackTable = map[string]Element{
	"累":    {Wuxing: "土", Celestial: "海王"},
	"想哭":   {Wuxing: "水", Celestial: "月亮"},
	"火大":   {Wuxing: "火", Celestial: "火星"},
	"好像懂了": {Wuxing: "金", Celestial: "天王"},
	"平":    {Wuxing: "土", Celestial: "海王"},
	"煩":    {Wuxing: "火", Celestial: "水星"},
	"爽":    {Wuxing: "火", Celestial: "太陽"},
	"開心":   {Wuxing: "火", Celestial: "木星"},
	"莫名":   {Wuxing: "靈質", Celestial: "海王"},
	"想睡":   {Wuxing: "水", Celestial: "海王"},
}

// FallbackAnalyze maps an emotion tag to a wuxing+celestial pair.
// Falls back to {靈質, 海王} for unknown tags.
func FallbackAnalyze(emotionTag string) FallbackResult {
	key := strings.TrimSpace(emotionTag)
	if elem, ok := FallbackTable[key]; ok {
		return FallbackResult{
			WuxingDetected:    elem.Wuxing,
			CelestialDetected: elem.Celestial,
			Status:            fallbackStatus,
			FallbackReason:    fallbackReason,
		}
	}
	return FallbackResult{
		WuxingDetected:    "靈質",
		CelestialDetected: "海王",
		Status:            fallbackStatus,
		FallbackReason:    fallbackReason,
	}
}

// RetryWithFallback calls the LLM up to 3 times with exponential backoff (1s/3s/10s).
// If all attempts fail, returns a heuristic result from FallbackAnalyze.
func RetryWithFallback(ctx context.Context, client LLMClient, req AnalysisRequest) (AnalysisResult, bool, error) {
	delays := []time.Duration{0, 1 * time.Second, 3 * time.Second}
	var lastErr error
	for i, d := range delays {
		if i > 0 {
			select {
			case <-time.After(d):
			case <-ctx.Done():
				return AnalysisResult{}, false, ctx.Err()
			}
		}
		r, e := client.Analyze(ctx, req)
		if e == nil {
			return r, false, nil
		}
		lastErr = e
	}
	fb := FallbackAnalyze(req.EmotionTag)
	return AnalysisResult{
		WuxingDetected:    fb.WuxingDetected,
		CelestialDetected: fb.CelestialDetected,
	}, true, lastErr
}
