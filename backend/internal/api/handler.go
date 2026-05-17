package api

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

// WritingRequest is the POST /api/v1/writings request body.
type WritingRequest struct {
	Content       string `json:"content" binding:"required"`
	EmotionTag    string `json:"emotion_tag" binding:"required"`
	LocationAlias string `json:"location_alias"`
	WordCount     int    `json:"word_count"`
}

// WritingResponse is the 202 response for POST /api/v1/writings.
type WritingResponse struct {
	WritingID string `json:"writing_id"`
	Status    string `json:"status"`
}

// AnalysisResponse is the response for GET /api/v1/writings/:id/analysis.
type AnalysisResponse struct {
	Status            string  `json:"status"`
	WuxingDetected    string  `json:"wuxing_detected"`
	CelestialDetected string  `json:"celestial_detected"`
	MonsterName       *string `json:"monster_name,omitempty"`
	CardQuote         *string `json:"card_quote,omitempty"`
}

// Handler holds dependencies for the writing API endpoints.
type Handler struct {
	redis *redis.Client
	// TODO: add *sql.DB or pgxpool.Pool for real persistence
}

// NewHandler creates a Handler. redisClient may be nil in tests (queue push is skipped).
func NewHandler(redisClient *redis.Client) *Handler {
	return &Handler{redis: redisClient}
}

// PostWriting handles POST /api/v1/writings.
// Writes a pending record and enqueues it for AI analysis.
func (h *Handler) PostWriting(c *gin.Context) {
	var req WritingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	writingID := uuid.New().String()
	// TODO: INSERT INTO player_writings (id, content, emotion_tag, location_alias, word_count, status)
	//       VALUES ($1, $2, $3, $4, $5, 'PENDING_ANALYSIS')

	if h.redis != nil {
		task := map[string]interface{}{
			"writing_id":  writingID,
			"content":     req.Content,
			"emotion_tag": req.EmotionTag,
			"created_at":  time.Now().UTC().Format(time.RFC3339),
		}
		payload, _ := json.Marshal(task)
		// Ignore push error - background worker can recover via DB polling (TODO).
		_ = h.redis.RPush(c.Request.Context(), "writing_analysis_queue", payload)
	}

	c.JSON(http.StatusAccepted, WritingResponse{
		WritingID: writingID,
		Status:    "pending_analysis",
	})
}

// GetWritingAnalysis handles GET /api/v1/writings/:id/analysis.
// Polls the analysis result for the given writing ID.
func (h *Handler) GetWritingAnalysis(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing id"})
		return
	}
	// TODO: SELECT wuxing_detected, celestial_detected, monster_name, card_quote, status
	//       FROM player_writings WHERE id = $1
	c.JSON(http.StatusOK, AnalysisResponse{
		Status:            "pending_analysis",
		WuxingDetected:    "",
		CelestialDetected: "",
	})
}

// RegisterRoutes wires the writing API endpoints to the Gin router.
func RegisterRoutes(r *gin.Engine, h *Handler) {
	v1 := r.Group("/api/v1")
	{
		v1.POST("/writings", h.PostWriting)
		v1.GET("/writings/:id/analysis", h.GetWritingAnalysis)
	}
}
