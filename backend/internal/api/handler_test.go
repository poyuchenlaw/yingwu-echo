package api_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/simonchen/yingwu-echo/backend/internal/api"
)

func setupRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	h := api.NewHandler(nil, nil) // nil db + nil redis: stub path
	api.RegisterRoutes(r, h)
	return r
}

func TestPostWriting_ValidBody_Returns202(t *testing.T) {
	r := setupRouter()
	body := map[string]interface{}{
		"content":     "今天很累，但還是寫了",
		"emotion_tag": "累",
		"word_count":  10,
	}
	b, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/writings", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusAccepted {
		t.Errorf("expected 202, got %d; body: %s", w.Code, w.Body.String())
	}
	var resp map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatal("response is not valid JSON")
	}
	if resp["writing_id"] == "" || resp["writing_id"] == nil {
		t.Error("writing_id should be non-empty")
	}
	if resp["status"] != "pending_analysis" {
		t.Errorf("expected status pending_analysis, got %v", resp["status"])
	}
}

func TestPostWriting_MissingEmotionTag_Returns400(t *testing.T) {
	r := setupRouter()
	body := map[string]interface{}{
		"content": "no emotion tag provided",
	}
	b, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/writings", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestGetWritingAnalysis_Returns200WithStatus(t *testing.T) {
	r := setupRouter()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/writings/abc-123/analysis", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	var resp map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatal("response is not valid JSON")
	}
	if _, ok := resp["status"]; !ok {
		t.Error("response should contain status field")
	}
}
