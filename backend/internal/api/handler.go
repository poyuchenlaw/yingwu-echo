package api

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"github.com/simonchen/yingwu-echo/backend/internal/battle"
	"github.com/simonchen/yingwu-echo/backend/internal/faction"
	"github.com/simonchen/yingwu-echo/backend/internal/forge"
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

// AnalyzerFn is invoked asynchronously after a writing is inserted (v0.5 demo path).
// It receives the writing id, full content, and emotion tag; updates DB on completion.
type AnalyzerFn func(ctx context.Context, writingID, playerID, content, emotionTag string)

// DefaultPlayerID is used when no auth/session layer exists (v0.5).
const DefaultPlayerID = "00000000-0000-0000-0000-000000000001"

// playerIDFromHeader returns a valid UUID from X-Player-Id, or DefaultPlayerID
// if the header is missing or malformed (back-compat with v0.5 clients).
func playerIDFromHeader(c *gin.Context) string {
	raw := strings.TrimSpace(c.GetHeader("X-Player-Id"))
	if raw == "" {
		return DefaultPlayerID
	}
	if _, err := uuid.Parse(raw); err != nil {
		return DefaultPlayerID
	}
	return raw
}

// WritingListItem represents one row in GET /api/v1/writings list response.
type WritingListItem struct {
	ID                string  `json:"id"`
	Content           string  `json:"content"`
	EmotionTag        string  `json:"emotion_tag"`
	LocationAlias     string  `json:"location_alias"`
	WuxingDetected    string  `json:"wuxing_detected"`
	CelestialDetected string  `json:"celestial_detected"`
	MonsterName       string  `json:"monster_name"`
	CardQuote         string  `json:"card_quote"`
	ValidityScore     float64 `json:"validity_score"`
	Status            string  `json:"status"`
	WrittenAt         string  `json:"written_at"`
	AnalyzedAt        string  `json:"analyzed_at,omitempty"`
}

// Handler holds dependencies for the writing API endpoints.
type Handler struct {
	db       *sql.DB
	redis    *redis.Client
	analyzer AnalyzerFn
}

// NewHandler creates a Handler. db, redisClient, analyzer may all be nil in tests:
//   - nil db: PostWriting/GetWritingAnalysis return stubs.
//   - nil redis: PostWriting skips the queue push.
//   - nil analyzer: PostWriting skips inline analysis kickoff.
func NewHandler(db *sql.DB, redisClient *redis.Client) *Handler {
	return &Handler{db: db, redis: redisClient}
}

// SetAnalyzer wires the background analyzer fn (called after each successful insert).
func (h *Handler) SetAnalyzer(fn AnalyzerFn) { h.analyzer = fn }

// PostWriting handles POST /api/v1/writings.
// db!=nil: INSERTs row, kicks off background analyzer goroutine.
// db==nil: stub path (writing_id returned but nothing persisted).
func (h *Handler) PostWriting(c *gin.Context) {
	var req WritingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	writingID := uuid.New().String()

	playerID := playerIDFromHeader(c)

	if h.db != nil {
		hash := sha256.Sum256([]byte(req.Content))
		charCount := req.WordCount
		if charCount == 0 {
			charCount = len([]rune(req.Content))
		}
		_, err := h.db.ExecContext(c.Request.Context(),
			`INSERT INTO player_writings
			 (id, player_id, content, content_hash, char_count, emotion_tag, location_alias, status)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending_analysis')`,
			writingID, playerID, req.Content, hex.EncodeToString(hash[:]),
			charCount, req.EmotionTag, req.LocationAlias)
		if err != nil {
			// Detect unique-violation on content_hash (dedup protection)
			if strings.Contains(err.Error(), "uniq_player_writings_content_hash") {
				var existingID string
				if e := h.db.QueryRowContext(c.Request.Context(),
					`SELECT id FROM player_writings WHERE player_id=$1 AND content_hash=$2 LIMIT 1`,
					playerID, hex.EncodeToString(hash[:])).Scan(&existingID); e == nil {
					c.JSON(http.StatusConflict, gin.H{
						"error":      "duplicate writing (same content already submitted)",
						"writing_id": existingID,
					})
					return
				}
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": "db insert: " + err.Error()})
			return
		}
		if h.analyzer != nil {
			go func() {
				ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
				defer cancel()
				h.analyzer(ctx, writingID, playerID, req.Content, req.EmotionTag)
			}()
		} else {
			log.Printf("PostWriting: analyzer not set, row %s stays pending_analysis", writingID)
		}
	}

	if h.redis != nil {
		task := map[string]interface{}{
			"writing_id":  writingID,
			"content":     req.Content,
			"emotion_tag": req.EmotionTag,
			"created_at":  time.Now().UTC().Format(time.RFC3339),
		}
		payload, _ := json.Marshal(task)
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
		v1.GET("/writings", h.GetWritings)
		v1.GET("/writings/:id/analysis", h.GetWritingAnalysis)
		v1.GET("/monsters", h.GetMonsters)
		v1.POST("/forge", h.PostForge)
		v1.POST("/dev/seed-cards", h.DevSeedCards)
		v1.POST("/battle", h.PostBattle)
	}
}

// GetWritings handles GET /api/v1/writings?limit=50&offset=0.
// Returns a list of writings for the player identified by X-Player-Id header
// (or DefaultPlayerID if missing), newest first.
func (h *Handler) GetWritings(c *gin.Context) {
	if h.db == nil {
		c.JSON(http.StatusOK, gin.H{"writings": []WritingListItem{}})
		return
	}
	playerID := playerIDFromHeader(c)
	limit := 50
	offset := 0
	if q := c.Query("limit"); q != "" {
		var v int
		if _, err := fmt.Sscanf(q, "%d", &v); err == nil && v > 0 && v <= 200 {
			limit = v
		}
	}
	if q := c.Query("offset"); q != "" {
		var v int
		if _, err := fmt.Sscanf(q, "%d", &v); err == nil && v >= 0 {
			offset = v
		}
	}
	rows, err := h.db.QueryContext(c.Request.Context(),
		`SELECT id, content, emotion_tag, COALESCE(location_alias, ''),
		        COALESCE(wuxing_detected::text, ''), COALESCE(celestial_detected, ''),
		        COALESCE(monster_name, ''), COALESCE(card_quote, ''),
		        validity_score, status, written_at, analyzed_at
		 FROM player_writings
		 WHERE player_id = $1
		 ORDER BY written_at DESC
		 LIMIT $2 OFFSET $3`,
		playerID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()
	out := make([]WritingListItem, 0, limit)
	for rows.Next() {
		var (
			it         WritingListItem
			writtenAt  time.Time
			analyzedAt sql.NullTime
		)
		if err := rows.Scan(&it.ID, &it.Content, &it.EmotionTag, &it.LocationAlias,
			&it.WuxingDetected, &it.CelestialDetected, &it.MonsterName, &it.CardQuote,
			&it.ValidityScore, &it.Status, &writtenAt, &analyzedAt); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		it.WrittenAt = writtenAt.UTC().Format(time.RFC3339)
		if analyzedAt.Valid {
			it.AnalyzedAt = analyzedAt.Time.UTC().Format(time.RFC3339)
		}
		out = append(out, it)
	}
	c.JSON(http.StatusOK, gin.H{"writings": out})
}

// WuxingCNtoEN maps Chinese wuxing labels to the DB enum values.
var WuxingCNtoEN = map[string]string{
	"金": "metal",
	"木": "wood",
	"水": "water",
	"火": "fire",
	"土": "earth",
}

// UpdateWritingAnalysis writes Gemini analysis back to player_writings.
// Used by the analyzer goroutine wired in main.go.
func (h *Handler) UpdateWritingAnalysis(ctx context.Context, writingID, wuxingCN, celestial, monsterName, cardQuote string, validityScore float64) error {
	wuxingEN, ok := WuxingCNtoEN[wuxingCN]
	if !ok {
		wuxingEN = "earth" // safe default for unknown
	}
	// Clamp validity score to [0,1]
	if validityScore < 0 {
		validityScore = 0
	}
	if validityScore > 1 {
		validityScore = 1
	}
	// Truncate card_quote/monster_name to fit varchar limits (defensive)
	cardQuote = truncRunes(cardQuote, 120)
	monsterName = truncRunes(monsterName, 80)
	_, err := h.db.ExecContext(ctx,
		`UPDATE player_writings
		 SET status='COMPLETE',
		     wuxing_detected=$1::wuxing,
		     celestial_detected=$2,
		     monster_name=$3,
		     card_quote=$4,
		     validity_score=$5,
		     analyzed_at=now()
		 WHERE id=$6`,
		wuxingEN, celestial, monsterName, cardQuote, validityScore, writingID)
	return err
}

// MarkWritingFailed sets the writing status to FAILED so polling can stop.
func (h *Handler) MarkWritingFailed(ctx context.Context, writingID, reason string) error {
	_, err := h.db.ExecContext(ctx,
		`UPDATE player_writings SET status='FAILED', analyzed_at=now() WHERE id=$1`,
		writingID)
	log.Printf("MarkWritingFailed id=%s reason=%s err=%v", writingID, reason, err)
	return err
}

func truncRunes(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n])
}

// MonsterCard is the lightweight summary used by GET /api/v1/monsters.
type MonsterCard struct {
	ID          string  `json:"id"`
	VariantID   string  `json:"variant_id"`
	SpeciesName string  `json:"species_name"`
	WuxingAttr  string  `json:"wuxing_attr"`
	Rarity      string  `json:"rarity"`
	PowerBase   int     `json:"power_base"`
	HPBase      int     `json:"hp_base"`
	Position    string  `json:"position"`
	Nickname    *string `json:"nickname,omitempty"`
	AcquiredAt  string  `json:"acquired_at"`
}

// AcquireMonsterForWriting picks a variant matching (emotionTag, wuxingEN) and
// inserts a player_monsters row. Falls back to any variant for that emotion if
// the precise wuxing match is missing, then to any variant at all.
func (h *Handler) AcquireMonsterForWriting(ctx context.Context, playerID, emotionTag, wuxingEN, nickname string) (string, error) {
	if h.db == nil {
		return "", nil
	}
	var variantID string
	// Try precise: species.emotion_tag=$1 AND variant.wuxing_attr=$2
	err := h.db.QueryRowContext(ctx,
		`SELECT v.id FROM monster_variants v
		 JOIN monster_species s ON s.id=v.species_id
		 WHERE s.emotion_tag=$1 AND v.wuxing_attr=$2::wuxing AND v.rarity='common'
		 ORDER BY RANDOM() LIMIT 1`,
		emotionTag, wuxingEN).Scan(&variantID)
	if err == sql.ErrNoRows {
		err = h.db.QueryRowContext(ctx,
			`SELECT v.id FROM monster_variants v
			 JOIN monster_species s ON s.id=v.species_id
			 WHERE s.emotion_tag=$1 AND v.rarity='common'
			 ORDER BY RANDOM() LIMIT 1`,
			emotionTag).Scan(&variantID)
	}
	if err == sql.ErrNoRows {
		err = h.db.QueryRowContext(ctx,
			`SELECT id FROM monster_variants WHERE rarity='common' ORDER BY RANDOM() LIMIT 1`).Scan(&variantID)
	}
	if err != nil {
		return "", err
	}
	monsterID := uuid.New().String()
	var nick interface{}
	if nickname != "" {
		nick = nickname
	}
	_, err = h.db.ExecContext(ctx,
		`INSERT INTO player_monsters (id, player_id, variant_id, nickname)
		 VALUES ($1, $2, $3, $4)`,
		monsterID, playerID, variantID, nick)
	if err != nil {
		return "", err
	}
	return monsterID, nil
}

// GetMonsters returns the player's monster collection.
func (h *Handler) GetMonsters(c *gin.Context) {
	if h.db == nil {
		c.JSON(http.StatusOK, gin.H{"monsters": []MonsterCard{}, "stub_mode": true})
		return
	}
	rows, err := h.db.QueryContext(c.Request.Context(),
		`SELECT pm.id, pm.variant_id, s.name_zh, v.wuxing_attr::text, v.rarity::text,
		        v.power_base, v.hp_base, v.position::text, pm.nickname, pm.acquired_at
		 FROM player_monsters pm
		 JOIN monster_variants v ON v.id=pm.variant_id
		 JOIN monster_species s ON s.id=v.species_id
		 WHERE pm.player_id=$1 AND pm.is_active=true
		 ORDER BY pm.acquired_at DESC LIMIT 100`,
		DefaultPlayerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()
	cards := []MonsterCard{}
	for rows.Next() {
		var m MonsterCard
		var nick sql.NullString
		var acq time.Time
		if err := rows.Scan(&m.ID, &m.VariantID, &m.SpeciesName, &m.WuxingAttr, &m.Rarity,
			&m.PowerBase, &m.HPBase, &m.Position, &nick, &acq); err != nil {
			continue
		}
		if nick.Valid {
			v := nick.String
			m.Nickname = &v
		}
		m.AcquiredAt = acq.UTC().Format(time.RFC3339)
		cards = append(cards, m)
	}
	c.JSON(http.StatusOK, gin.H{"monsters": cards, "count": len(cards)})
}

// ForgeRequest is POST /api/v1/forge body.
type ForgeAPIRequest struct {
	SourceIDs        []string `json:"source_ids" binding:"required"`
	TargetRarity     string   `json:"target_rarity" binding:"required"` // "rare" | "legendary"
	CharsAccumulated int      `json:"chars_accumulated"`
}

// PostForge handles POST /api/v1/forge.
func (h *Handler) PostForge(c *gin.Context) {
	if h.db == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "forge requires DATABASE_URL"})
		return
	}
	var req ForgeAPIRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	pid, err := uuid.Parse(DefaultPlayerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "default player id parse: " + err.Error()})
		return
	}
	srcs := make([]uuid.UUID, 0, len(req.SourceIDs))
	for _, id := range req.SourceIDs {
		u, e := uuid.Parse(id)
		if e != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "bad source id " + id})
			return
		}
		srcs = append(srcs, u)
	}
	target := forge.RarityTier(req.TargetRarity)
	chars := req.CharsAccumulated
	if chars == 0 {
		// derive from player_writings sum
		_ = h.db.QueryRowContext(c.Request.Context(),
			`SELECT COALESCE(SUM(char_count),0) FROM player_writings WHERE player_id=$1`,
			DefaultPlayerID).Scan(&chars)
	}
	// Wrap forge in transaction (ADR-002 v2 §2.8): rollback on any failure so
	// global_legendary_count + player_monsters + forge_records stay consistent.
	tx, err := h.db.BeginTx(c.Request.Context(), nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "begin tx: " + err.Error()})
		return
	}
	newID, err := forge.TryForge(forge.WrapDB2(tx), pid, srcs, target, chars)
	if err != nil {
		_ = tx.Rollback()
		log.Printf("PostForge err (rolled back): %v", err)
		var capErr *forge.LegendaryCapError
		if errors.As(err, &capErr) {
			// Legendary cap is a "controlled" failure — tx rolled back above.
			// Per ADR §2.5 refund 80% of materials; v0.6+ snapshot enables
			// returning the EXACT consumed variants instead of random commons.
			keep := int(float64(len(capErr.VariantIDs))*0.8 + 0.5)
			refunded := h.refundExactVariants(c.Request.Context(), capErr.VariantIDs[:keep])
			c.JSON(http.StatusConflict, gin.H{
				"error":             "legendary cap reached (99 active globally for that species)",
				"refunded_card_ids": refunded,
				"refund_pct":        80,
				"refunded_exact":    true,
			})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "commit: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"forged_monster_id": newID.String(),
		"target_rarity":     req.TargetRarity,
		"sources_consumed":  len(srcs),
		"chars_used":        chars,
	})
}

// DevSeedCards (POST /api/v1/dev/seed-cards) inserts 3 same-(emotion,wuxing) common cards
// for the default player so forge can be exercised without grinding writes.
func (h *Handler) DevSeedCards(c *gin.Context) {
	if h.db == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "seed requires DATABASE_URL"})
		return
	}
	emotion := c.DefaultQuery("emotion", "累")
	wuxing := c.DefaultQuery("wuxing", "water")
	// find 3 distinct variants matching (emotion, wuxing); if <3 distinct, repeat
	rows, err := h.db.QueryContext(c.Request.Context(),
		`SELECT v.id FROM monster_variants v
		 JOIN monster_species s ON s.id=v.species_id
		 WHERE s.emotion_tag=$1 AND v.wuxing_attr=$2::wuxing AND v.rarity='common'
		 ORDER BY RANDOM() LIMIT 3`,
		emotion, wuxing)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()
	vids := []string{}
	for rows.Next() {
		var v string
		_ = rows.Scan(&v)
		vids = append(vids, v)
	}
	if len(vids) == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "no variants for that emotion+wuxing"})
		return
	}
	// pad to 3 by repeating
	for len(vids) < 3 {
		vids = append(vids, vids[0])
	}
	created := []string{}
	for _, v := range vids[:3] {
		mid := uuid.New().String()
		_, err := h.db.ExecContext(c.Request.Context(),
			`INSERT INTO player_monsters (id, player_id, variant_id) VALUES ($1, $2, $3)`,
			mid, DefaultPlayerID, v)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		created = append(created, mid)
	}
	c.JSON(http.StatusOK, gin.H{
		"created": created,
		"emotion": emotion,
		"wuxing":  wuxing,
		"hint":    "now POST /api/v1/forge with these source_ids + target_rarity='rare'",
	})
}

// SystemNPCPlayerID owns wild NPC monsters available for battle.
const SystemNPCPlayerID = "00000000-0000-0000-0000-FFFFFFFFFFFF"

// BattleRequest is POST /api/v1/battle body.
type BattleAPIRequest struct {
	AttackerMonsterID string `json:"attacker_monster_id" binding:"required"`
}

// BattleRound describes a single damage round in the report.
type BattleRound struct {
	Turn       int    `json:"turn"`
	Actor      string `json:"actor"`
	Damage     int    `json:"damage"`
	DefenderHP int    `json:"defender_hp"`
	AttackerHP int    `json:"attacker_hp"`
}

// BattleResult is the verbose response of POST /api/v1/battle.
type BattleResult struct {
	BattleID            string        `json:"battle_id"`
	AttackerSpecies     string        `json:"attacker_species"`
	AttackerWuxing      string        `json:"attacker_wuxing"`
	DefenderSpecies     string        `json:"defender_species"`
	DefenderWuxing      string        `json:"defender_wuxing"`
	DefenderNickname    string        `json:"defender_nickname"`
	Multiplier          float64       `json:"damage_multiplier"`
	Rounds              []BattleRound `json:"rounds"`
	Outcome             string        `json:"outcome"`
	MirrorWindowOpened  bool          `json:"mirror_window_opened"`
	ReverseGambit       bool          `json:"reverse_gambit_triggered"`
	ImprintAttempted    bool          `json:"imprint_attempted"`
	ImprintSuccess      bool          `json:"imprint_success"`
	ImprintProbability  float64       `json:"imprint_probability"`
	CapturedMonsterID   *string       `json:"captured_monster_id,omitempty"`
	CapturedNickname    *string       `json:"captured_nickname,omitempty"`
}

// PostBattle handles POST /api/v1/battle. Picks a random NPC defender, runs the
// engine, persists battles row, optionally imprints captured monster to player.
func (h *Handler) PostBattle(c *gin.Context) {
	if h.db == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "battle requires DATABASE_URL"})
		return
	}
	var req BattleAPIRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Load attacker
	var attWuxing, attSpecies string
	var attPower, attHP int
	err := h.db.QueryRowContext(c.Request.Context(),
		`SELECT v.wuxing_attr::text, s.name_zh, v.power_base, v.hp_base
		 FROM player_monsters pm
		 JOIN monster_variants v ON v.id=pm.variant_id
		 JOIN monster_species s ON s.id=v.species_id
		 WHERE pm.id=$1 AND pm.player_id=$2 AND pm.is_active=true`,
		req.AttackerMonsterID, DefaultPlayerID).Scan(&attWuxing, &attSpecies, &attPower, &attHP)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "attacker monster not found in your collection"})
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Pick random NPC defender
	var defID, defVariantID, defWuxing, defSpecies, defNick string
	var defPower, defHP int
	err = h.db.QueryRowContext(c.Request.Context(),
		`SELECT pm.id, pm.variant_id, v.wuxing_attr::text, s.name_zh, pm.nickname,
		        v.power_base, v.hp_base
		 FROM player_monsters pm
		 JOIN monster_variants v ON v.id=pm.variant_id
		 JOIN monster_species s ON s.id=v.species_id
		 WHERE pm.player_id=$1 AND pm.is_active=true
		 ORDER BY RANDOM() LIMIT 1`,
		SystemNPCPlayerID).Scan(&defID, &defVariantID, &defWuxing, &defSpecies, &defNick, &defPower, &defHP)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "pick npc: " + err.Error()})
		return
	}

	// Build engine monsters
	attUUID, _ := uuid.Parse(req.AttackerMonsterID)
	defUUID, _ := uuid.Parse(defID)
	playerUUID, _ := uuid.Parse(DefaultPlayerID)
	npcUUID, _ := uuid.Parse(SystemNPCPlayerID)
	attMonster := &battle.Monster{
		ID: attUUID, OwnerID: playerUUID, Wuxing: battle.Wuxing(attWuxing),
		PowerBase: attPower, MaxHP: attHP, CurrentHP: attHP,
	}
	defMonster := &battle.Monster{
		ID: defUUID, OwnerID: npcUUID, Wuxing: battle.Wuxing(defWuxing),
		PowerBase: defPower, MaxHP: defHP, CurrentHP: defHP,
	}
	session, err := battle.NewSession(attMonster, defMonster)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "new session: " + err.Error()})
		return
	}
	_ = session.Summon()

	// Determine target rarity from defender
	var defRarity string
	_ = h.db.QueryRowContext(c.Request.Context(),
		`SELECT rarity::text FROM monster_variants WHERE id=$1`, defVariantID).Scan(&defRarity)
	switch defRarity {
	case "rare":
		session.TargetRarity = battle.RarityRare
	case "legendary":
		session.TargetRarity = battle.RarityLegendary
	default:
		session.TargetRarity = battle.RarityCommon
	}

	mult := battle.DamageMultiplier(attMonster.Wuxing, defMonster.Wuxing)
	rounds := []BattleRound{}
	turn := 0
	mirrorOpened := false
	for attMonster.CurrentHP > 0 && defMonster.CurrentHP > 0 && turn < 12 {
		turn++
		atkDmg := battle.CalculateDamage(attMonster, defMonster, attMonster.PowerBase*10)
		defMonster.CurrentHP -= atkDmg
		if defMonster.CurrentHP < 0 {
			defMonster.CurrentHP = 0
		}
		rounds = append(rounds, BattleRound{turn, "attacker", atkDmg, defMonster.CurrentHP, attMonster.CurrentHP})
		// Check reverse gambit on defender HP <30%
		if session.CheckReverseGambit() && !mirrorOpened {
			mirrorOpened = true
			break
		}
		if defMonster.CurrentHP == 0 {
			break
		}
		defDmg := battle.CalculateDamage(defMonster, attMonster, defMonster.PowerBase*10)
		attMonster.CurrentHP -= defDmg
		if attMonster.CurrentHP < 0 {
			attMonster.CurrentHP = 0
		}
		rounds = append(rounds, BattleRound{turn, "defender", defDmg, defMonster.CurrentHP, attMonster.CurrentHP})
	}

	// Outcome + imprint attempt
	outcome := "draw"
	imprintAttempted := false
	imprintSuccess := false
	var capturedID, capturedNick *string
	var imprintProb float64

	if defMonster.CurrentHP == 0 {
		outcome = "attacker_won"
		// Auto open mirror window if not yet open via reverse gambit
		if !mirrorOpened {
			if e := session.OpenMirrorWindow(); e == nil {
				mirrorOpened = true
			}
		}
	} else if attMonster.CurrentHP == 0 {
		outcome = "defender_won"
	} else if mirrorOpened {
		outcome = "mirror_window_open"
	}

	if mirrorOpened {
		imprintAttempted = true
		// Resolve player's faction modifiers for imprint_attempt phase (may be nil)
		mods, _ := faction.ResolveImprintModifiers(faction.WrapDB(h.db), playerUUID, faction.PhaseImprintAttempt)
		imprintProb = battle.ImprintProbability(session.TargetRarity, mods)
		ok, _ := session.TryImprint(mods)
		imprintSuccess = ok
		if ok {
			// Imprint: insert a new player_monsters row for the player, referencing the captured variant
			newMID := uuid.New().String()
			newNick := "戰利·" + defSpecies
			_, err := h.db.ExecContext(c.Request.Context(),
				`INSERT INTO player_monsters (id, player_id, variant_id, nickname, imprinted_from_player_id, lock_state)
				 VALUES ($1, $2, $3, $4, $5, 'free')`,
				newMID, DefaultPlayerID, defVariantID, newNick, SystemNPCPlayerID)
			if err == nil {
				capturedID = &newMID
				capturedNick = &newNick
			} else {
				// INSERT failed — demote outcome so battles.state reflects reality
				log.Printf("battle imprint insert failed (demoting to returned_to_owner): %v", err)
				imprintSuccess = false
			}
		}
	}

	// Persist battles row
	battleID := uuid.New().String()
	state := "returned_to_owner"
	if imprintSuccess {
		state = "captured"
	}
	var capturedMonsterFKValue interface{}
	if capturedID != nil {
		capturedMonsterFKValue = *capturedID
	}
	_, _ = h.db.ExecContext(c.Request.Context(),
		`INSERT INTO battles (id, attacker_player_id, defender_player_id, attacker_monster_id, defender_monster_id, state, captured_monster_id, reverse_gambit_triggered, ended_at)
		 VALUES ($1, $2, $3, $4, $5, $6::battle_state, $7, $8, NOW())`,
		battleID, DefaultPlayerID, SystemNPCPlayerID, req.AttackerMonsterID, defID, state, capturedMonsterFKValue, session.ReverseTriggered)

	c.JSON(http.StatusOK, BattleResult{
		BattleID:           battleID,
		AttackerSpecies:    attSpecies,
		AttackerWuxing:     attWuxing,
		DefenderSpecies:    defSpecies,
		DefenderWuxing:     defWuxing,
		DefenderNickname:   defNick,
		Multiplier:         mult,
		Rounds:             rounds,
		Outcome:            outcome,
		MirrorWindowOpened: mirrorOpened,
		ReverseGambit:      session.ReverseTriggered,
		ImprintAttempted:   imprintAttempted,
		ImprintSuccess:     imprintSuccess,
		ImprintProbability: imprintProb,
		CapturedMonsterID:  capturedID,
		CapturedNickname:   capturedNick,
	})
}

// refundForgeMaterials reinserts up to n source cards as fresh player_monsters rows.
// Used on legendary cap failure to restore 80% of materials per ADR §2.5.
// Returns the new monster ids that succeeded.
func (h *Handler) refundForgeMaterials(ctx context.Context, sourceIDs []uuid.UUID, n int) []string {
	if n > len(sourceIDs) {
		n = len(sourceIDs)
	}
	out := []string{}
	for i := 0; i < n; i++ {
		// Lookup the variant_id for the consumed source (was deleted by TryForge step 5,
		// so we cannot recover the exact card; in production we would snapshot pre-delete.
		// For v0.5: insert a placeholder common variant matching player's emotion tag.
		var variantID string
		err := h.db.QueryRowContext(ctx,
			`SELECT id FROM monster_variants WHERE rarity='common' ORDER BY RANDOM() LIMIT 1`).Scan(&variantID)
		if err != nil {
			continue
		}
		mid := uuid.New().String()
		_, err = h.db.ExecContext(ctx,
			`INSERT INTO player_monsters (id, player_id, variant_id, nickname)
			 VALUES ($1, $2, $3, $4)`,
			mid, DefaultPlayerID, variantID, "退材·forge_cap")
		if err == nil {
			out = append(out, mid)
		}
	}
	return out
}

// refundExactVariants reinserts player_monsters rows with the exact variant_ids
// snapshotted before TryForge deleted them (v0.6 enhancement of refundForgeMaterials).
// Caller passes the slice already truncated to the keep-count.
func (h *Handler) refundExactVariants(ctx context.Context, variantIDs []uuid.UUID) []string {
	out := []string{}
	for _, vid := range variantIDs {
		mid := uuid.New().String()
		_, err := h.db.ExecContext(ctx,
			`INSERT INTO player_monsters (id, player_id, variant_id, nickname)
			 VALUES ($1, $2, $3, $4)`,
			mid, DefaultPlayerID, vid.String(), "退材·原 variant")
		if err == nil {
			out = append(out, mid)
		}
	}
	return out
}
