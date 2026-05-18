package analyzer

import "context"

// AnalysisRequest is the input to the LLM analysis pipeline.
type AnalysisRequest struct {
	WritingID  string
	Content    string
	EmotionTag string
}

// AnalysisResult is the structured output from the LLM or fallback heuristic.
type AnalysisResult struct {
	WuxingDetected    string
	CelestialDetected string
	CardQuote         string
	MonsterName       string
	ValidityScore     float64
}

// LLMClient abstracts the AI analysis backend.
// Real implementation uses Gemini Flash; tests use MockLLMClient.
type LLMClient interface {
	Analyze(ctx context.Context, req AnalysisRequest) (AnalysisResult, error)
}

// MockLLMClient is a test double that returns deterministic results.
// TODO: replace with GeminiClient when API key is configured.
type MockLLMClient struct{}

// v0.6.4: WuxingDetected returns CN ("火") to match Gemini live output and
// what UpdateWritingAnalysis/AcquireMonsterForWriting expect (WuxingCNtoEN
// map keys are CN). Prior "fire" EN value caused silent fallback to "earth"
// across all writings — invisible in mock dev runs.
func (m *MockLLMClient) Analyze(_ context.Context, _ AnalysisRequest) (AnalysisResult, error) {
	return AnalysisResult{
		WuxingDetected:    "火",
		CelestialDetected: "太陽",
		CardQuote:         "mock card quote",
		MonsterName:       "mock monster",
		ValidityScore:     0.5,
	}, nil
}
