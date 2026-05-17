package analyzer

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/simonchen/yingwu-echo/backend/internal/analyzer/prompts"
)

const (
	defaultGeminiModel   = "gemini-2.5-flash"
	defaultGeminiTimeout = 15 * time.Second
)

var geminiAPIBase = "https://generativelanguage.googleapis.com/v1beta/models"

// GeminiClient calls the Gemini generateContent API for writing analysis.
type GeminiClient struct {
	apiKey     string
	model      string
	httpClient *http.Client
}

var _ LLMClient = (*GeminiClient)(nil)

// NewGeminiClient creates a Gemini-backed LLM client.
func NewGeminiClient(apiKey, model string, timeout time.Duration) (*GeminiClient, error) {
	if strings.TrimSpace(apiKey) == "" {
		return nil, fmt.Errorf("gemini api key is required")
	}
	if strings.TrimSpace(model) == "" {
		model = defaultGeminiModel
	}
	if timeout <= 0 {
		timeout = defaultGeminiTimeout
	}
	return &GeminiClient{
		apiKey: strings.TrimSpace(apiKey),
		model:  strings.TrimSpace(model),
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}, nil
}

// Analyze sends the writing request to Gemini and returns parsed analysis.
func (c *GeminiClient) Analyze(ctx context.Context, req AnalysisRequest) (AnalysisResult, error) {
	// TODO(v0.6): pass scene from AnalysisRequest when scene tags are modeled.
	prompt := prompts.BuildPrompt(req.EmotionTag, "通勤", req.Content)
	body, err := json.Marshal(geminiRequest{
		Contents: []geminiContent{{
			Role:  "user",
			Parts: []geminiPart{{Text: prompt}},
		}},
	})
	if err != nil {
		return AnalysisResult{}, fmt.Errorf("marshal gemini request: %w", err)
	}

	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			if err := sleepWithContext(ctx, retryDelay(attempt)); err != nil {
				return AnalysisResult{}, err
			}
		}

		result, retryable, err := c.analyzeOnce(ctx, body)
		if err == nil {
			return result, nil
		}
		lastErr = err
		if !retryable {
			return AnalysisResult{}, err
		}
	}
	return AnalysisResult{}, fmt.Errorf("gemini request exhausted after 3 attempts: %w", lastErr)
}

func (c *GeminiClient) analyzeOnce(ctx context.Context, body []byte) (AnalysisResult, bool, error) {
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint(), bytes.NewReader(body))
	if err != nil {
		return AnalysisResult{}, false, fmt.Errorf("create gemini request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		if ctx.Err() != nil {
			return AnalysisResult{}, false, ctx.Err()
		}
		return AnalysisResult{}, true, fmt.Errorf("gemini request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return AnalysisResult{}, true, fmt.Errorf("read gemini response: %w", err)
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		err := fmt.Errorf("gemini status code %d: %s", resp.StatusCode, truncateBody(respBody))
		return AnalysisResult{}, isRetryableStatus(resp.StatusCode), err
	}

	var envelope geminiResponse
	if err := json.Unmarshal(respBody, &envelope); err != nil {
		return AnalysisResult{}, false, fmt.Errorf("parse gemini response envelope: %w", err)
	}
	text, err := envelopeText(envelope)
	if err != nil {
		return AnalysisResult{}, false, err
	}
	wuxing, celestial, monster, quote, score, err := prompts.ParseAnalysis(text)
	if err != nil {
		return AnalysisResult{}, false, fmt.Errorf("parse gemini analysis: %w", err)
	}
	return AnalysisResult{
		WuxingDetected:    wuxing,
		CelestialDetected: celestial,
		MonsterName:       monster,
		CardQuote:         quote,
		ValidityScore:     score,
	}, false, nil
}

func (c *GeminiClient) endpoint() string {
	base := strings.TrimRight(geminiAPIBase, "/")
	u, err := url.Parse(base + "/" + url.PathEscape(c.model) + ":generateContent")
	if err != nil {
		return base + "/" + url.PathEscape(c.model) + ":generateContent?key=" + url.QueryEscape(c.apiKey)
	}
	q := u.Query()
	q.Set("key", c.apiKey)
	u.RawQuery = q.Encode()
	return u.String()
}

func isRetryableStatus(code int) bool {
	return code == http.StatusTooManyRequests || code >= 500
}

func retryDelay(attempt int) time.Duration {
	if attempt == 1 {
		return 200 * time.Millisecond
	}
	return 600 * time.Millisecond
}

func sleepWithContext(ctx context.Context, d time.Duration) error {
	timer := time.NewTimer(d)
	defer timer.Stop()
	select {
	case <-timer.C:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func truncateBody(body []byte) string {
	const limit = 200
	text := string(body)
	runes := []rune(text)
	if len(runes) <= limit {
		return text
	}
	return string(runes[:limit])
}

func envelopeText(resp geminiResponse) (string, error) {
	if len(resp.Candidates) == 0 ||
		len(resp.Candidates[0].Content.Parts) == 0 ||
		resp.Candidates[0].Content.Parts[0].Text == "" {
		return "", fmt.Errorf("parse gemini response envelope: missing candidates[0].content.parts[0].text")
	}
	return resp.Candidates[0].Content.Parts[0].Text, nil
}

type geminiRequest struct {
	Contents []geminiContent `json:"contents"`
}

type geminiContent struct {
	Role  string       `json:"role,omitempty"`
	Parts []geminiPart `json:"parts"`
}

type geminiPart struct {
	Text string `json:"text"`
}

type geminiResponse struct {
	Candidates []struct {
		Content geminiContent `json:"content"`
	} `json:"candidates"`
}
