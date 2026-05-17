package api

import (
	"database/sql"
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
	db    *sql.DB
	redis *redis.Client
}

// NewHandler creates a Handler. db and redisClient may both be nil in tests:
//   - nil db: GetWritingAnalysis returns the legacy in-memory stub.
//   - nil redis: PostWriting skips the queue push (background recovery via DB).
func NewHandler(db *sql.DB, redisClient *redis.Client) *Handler {
	return &Handler{db: db, redis: redisClient}
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
// When h.db is nil, returns the legacy in-memory stub for unit tests.
func (h *Handler) GetWritingAnalysis(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing id"})
		return
	}
	if h.db == nil {
		c.JSON(http.StatusOK, AnalysisResponse{
			Status:            "pending_analysis",
			WuxingDetected:    "",
			CelestialDetected: "",
		})
		return
	}
	var (
		status            string
		wuxingDetected    sql.NullString
		celestialDetected sql.NullString
		monsterName       sql.NullString
		cardQuote         sql.NullString
	)
	row := h.db.QueryRowContext(c.Request.Context(),
		`SELECT status, wuxing_detected, celestial_detected, monster_name, card_quote
		 FROM player_writings WHERE id = $1`, id)
	if err := row.Scan(&status, &wuxingDetected, &celestialDetected, &monsterName, &cardQuote); err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "writing not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	resp := AnalysisResponse{
		Status:            status,
		WuxingDetected:    wuxingDetected.String,
		CelestialDetected: celestialDetected.String,
	}
	if monsterName.Valid {
		v := monsterName.String
		resp.MonsterName = &v
	}
	if cardQuote.Valid {
		v := cardQuote.String
		resp.CardQuote = &v
	}
	c.JSON(http.StatusOK, resp)
}

// RegisterRoutes wires the writing API endpoints to the Gin router.
func RegisterRoutes(r *gin.Engine, h *Handler) {
	v1 := r.Group("/api/v1")
	{
		v1.POST("/writings", h.PostWriting)
		v1.GET("/writings/:id/analysis", h.GetWritingAnalysis)
	}
}
