// Package forge implements the 應物 ECHO three-tier probability forge system.
//
// v0.3 (legacy, db=nil path, kept for backward compatibility):
//
//	L1 Common  : writing >= 50 chars -> 100% success
//	L2 Rare    : 3 same-species common + >= 200 chars + 3 emotion tags -> 30%
//	L3 Legendary: 3 same-species rare + >= 500 chars + 5 active days -> 10%
//
// v0.4 (db != nil path, new TryForge entrypoint):
//
//	Reads forge_recipes table for chars_required / source_count / source_rarity.
//	Validates source cards: count match, lock_state='free', emotion + wuxing match.
//	Legendary respects global_legendary_count.active_count <= 99 hard cap.
//	Destroys sources, inserts new player_monsters row, persists forge_records.
//	Uses SELECT FOR UPDATE on source cards (caller responsible for txn boundary).
package forge

import (
	"database/sql"
	"github.com/lib/pq"
	"errors"
	"fmt"
	"math/rand"
	"time"

	"github.com/google/uuid"
)

// RarityTier mirrors the DB enum.
type RarityTier string

const (
	RarityCommon    RarityTier = "common"
	RarityRare      RarityTier = "rare"
	RarityLegendary RarityTier = "legendary"
)

// ForgeRequest contains all inputs needed to evaluate a forge attempt (v0.3 legacy).
type ForgeRequest struct {
	TargetRarity    RarityTier
	ConsumedIDs     []string // must be exactly 3
	WritingChars    int
	EmotionTagCount int
	ActiveDays      int
}

// ForgeResult is the outcome of a forge attempt (v0.3 legacy).
type ForgeResult struct {
	Succeeded  bool
	Rarity     RarityTier
	RollValue  float64 // for audit / debugging
	FailReason string
}

var rng = rand.New(rand.NewSource(time.Now().UnixNano()))

// ============================================================
// v0.3 legacy API (db=nil path) — kept for forge_test.go tests 1-4
// ============================================================

// Attempt evaluates a forge request and returns the result.
// Does NOT write to DB — caller is responsible for persistence.
func Attempt(req ForgeRequest) (ForgeResult, error) {
	switch req.TargetRarity {
	case RarityCommon:
		return attemptCommon(req)
	case RarityRare:
		return attemptRare(req)
	case RarityLegendary:
		return attemptLegendary(req)
	default:
		return ForgeResult{}, errors.New("forge: unknown rarity tier")
	}
}

// attemptCommon: writing >= 50 chars -> 100% success.
func attemptCommon(req ForgeRequest) (ForgeResult, error) {
	if req.WritingChars < 50 {
		return ForgeResult{
			Succeeded:  false,
			Rarity:     RarityCommon,
			FailReason: "writing_chars < 50",
		}, nil
	}
	return ForgeResult{Succeeded: true, Rarity: RarityCommon, RollValue: 1.0}, nil
}

// attemptRare: 3 consumed + >= 200 chars + 3 emotion tags -> 30%.
func attemptRare(req ForgeRequest) (ForgeResult, error) {
	if len(req.ConsumedIDs) != 3 {
		return ForgeResult{FailReason: "need exactly 3 consumed monsters"}, nil
	}
	if req.WritingChars < 200 {
		return ForgeResult{FailReason: "writing_chars < 200"}, nil
	}
	if req.EmotionTagCount < 3 {
		return ForgeResult{FailReason: "emotion_tags < 3"}, nil
	}
	roll := rng.Float64()
	return ForgeResult{
		Succeeded:  roll < 0.30,
		Rarity:     RarityRare,
		RollValue:  roll,
		FailReason: condStr(roll >= 0.30, "probability_miss", ""),
	}, nil
}

// attemptLegendary: 3 rare consumed + >= 500 chars + 5 active days -> 10%.
func attemptLegendary(req ForgeRequest) (ForgeResult, error) {
	if len(req.ConsumedIDs) != 3 {
		return ForgeResult{FailReason: "need exactly 3 consumed monsters"}, nil
	}
	if req.WritingChars < 500 {
		return ForgeResult{FailReason: "writing_chars < 500"}, nil
	}
	if req.ActiveDays < 5 {
		return ForgeResult{FailReason: "active_days < 5"}, nil
	}
	roll := rng.Float64()
	return ForgeResult{
		Succeeded:  roll < 0.10,
		Rarity:     RarityLegendary,
		RollValue:  roll,
		FailReason: condStr(roll >= 0.10, "probability_miss", ""),
	}, nil
}

func condStr(cond bool, a, b string) string {
	if cond {
		return a
	}
	return b
}

// ============================================================
// v0.4 — DB-backed TryForge (ADR-002 v2 §2.3 / §2.5 / §2.8)
// ============================================================

// Sentinel errors so callers can branch on policy (esp. legendary cap retains 80% materials).
var (
	ErrLegendaryCapReached = errors.New("forge: global legendary cap (99) reached for species")
	ErrCharsBelowRequired  = errors.New("forge: writing chars below recipe requirement")
	ErrSourceCountMismatch = errors.New("forge: source card count does not match recipe")
	ErrEmotionMismatch     = errors.New("forge: source cards must share the same emotion tag")
	ErrWuxingMismatch      = errors.New("forge: source cards must share the same wuxing (rare target)")
	ErrSourceNotFree       = errors.New("forge: at least one source card is not in free lock_state")
	ErrRecipeNotFound      = errors.New("forge: no forge_recipe row found for target rarity")
	ErrUnknownTarget       = errors.New("forge: unknown target rarity")
)

// DBExecutor is the minimal surface of *sql.DB / *sql.Tx we need.
// Production code passes *sql.DB via WrapDB; tests pass a stub.
type DBExecutor interface {
	QueryRow(query string, args ...interface{}) RowScanner
	Exec(query string, args ...interface{}) (sql.Result, error)
}

// RowScanner is the minimal surface of *sql.Row we need.
type RowScanner interface {
	Scan(dest ...interface{}) error
}

// sqlDBAdapter wraps *sql.DB to satisfy DBExecutor.
type sqlDBAdapter struct{ db *sql.DB }

func (a *sqlDBAdapter) QueryRow(q string, args ...interface{}) RowScanner {
	return a.db.QueryRow(q, args...)
}
func (a *sqlDBAdapter) Exec(q string, args ...interface{}) (sql.Result, error) {
	return a.db.Exec(q, args...)
}

// WrapDB returns a DBExecutor backed by a real *sql.DB.
func WrapDB(db *sql.DB) DBExecutor {
	if db == nil {
		return nil
	}
	return &sqlDBAdapter{db: db}
}

// recipe captures one row from forge_recipes.
type recipe struct {
	SourceCount   int
	SourceRarity  string
	CharsRequired int
	ExtraMaterial sql.NullString // JSONB serialized
}

// sourceCardInfo represents a player_monsters row joined with variant + species metadata
// for forge eligibility evaluation.
type sourceCardInfo struct {
	ID         uuid.UUID
	VariantID  uuid.UUID
	SpeciesID  uuid.UUID
	Wuxing     string
	EmotionTag string
	Rarity     string
	LockState  string
}

// TryForge attempts a v0.4 DB-backed forge.
//
// On success returns the new player_monsters row id.
// On controlled failure returns a sentinel error (caller decides material refund policy).
// On infrastructure failure returns the wrapped DB error.
//
// Note: this function does NOT manage transactions; for production correctness callers
// should wrap the call in a BEGIN…COMMIT and pass a tx adapter satisfying DBExecutor.
// This keeps the function pure of txn policy while honoring ADR-002 v2 §2.8.
func TryForge(
	exec DBExecutor,
	playerID uuid.UUID,
	sourceCardIDs []uuid.UUID,
	targetRarity RarityTier,
	charsAccumulated int,
) (uuid.UUID, error) {
	if exec == nil {
		return uuid.Nil, errors.New("forge: DBExecutor is required for TryForge (use legacy Attempt for db=nil)")
	}
	if targetRarity != RarityRare && targetRarity != RarityLegendary {
		return uuid.Nil, ErrUnknownTarget
	}

	// Step 1: load recipe
	r, err := loadRecipe(exec, targetRarity)
	if err != nil {
		return uuid.Nil, err
	}

	// Step 2: load source cards
	cards, err := loadSourceCards(exec, playerID, sourceCardIDs)
	if err != nil {
		return uuid.Nil, err
	}

	// Step 3: validate
	if len(cards) != r.SourceCount {
		return uuid.Nil, fmt.Errorf("%w: expected %d, got %d", ErrSourceCountMismatch, r.SourceCount, len(cards))
	}
	if charsAccumulated < r.CharsRequired {
		return uuid.Nil, fmt.Errorf("%w: need %d, have %d", ErrCharsBelowRequired, r.CharsRequired, charsAccumulated)
	}
	for _, c := range cards {
		if c.LockState != "free" {
			return uuid.Nil, fmt.Errorf("%w: card %s lock_state=%s", ErrSourceNotFree, c.ID, c.LockState)
		}
		if c.Rarity != r.SourceRarity {
			return uuid.Nil, fmt.Errorf("forge: card %s rarity=%s, recipe requires %s", c.ID, c.Rarity, r.SourceRarity)
		}
	}
	// Emotion tag must match across all cards (both rare and legendary)
	firstEmotion := cards[0].EmotionTag
	for _, c := range cards[1:] {
		if c.EmotionTag != firstEmotion {
			return uuid.Nil, ErrEmotionMismatch
		}
	}
	// Wuxing must match for rare target (legendary unconstrained per ADR §2.3)
	if targetRarity == RarityRare {
		firstWuxing := cards[0].Wuxing
		for _, c := range cards[1:] {
			if c.Wuxing != firstWuxing {
				return uuid.Nil, ErrWuxingMismatch
			}
		}
	}

	// Step 4: legendary cap check + reservation
	if targetRarity == RarityLegendary {
		speciesID := cards[0].SpeciesID
		var active int
		err := exec.QueryRow(
			`SELECT active_count FROM global_legendary_count WHERE species_id = $1 FOR UPDATE`,
			speciesID,
		).Scan(&active)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return uuid.Nil, fmt.Errorf("forge: read global_legendary_count: %w", err)
		}
		if active >= 99 {
			return uuid.Nil, ErrLegendaryCapReached
		}
		if _, err := exec.Exec(
			`INSERT INTO global_legendary_count (species_id, active_count)
			 VALUES ($1, 1)
			 ON CONFLICT (species_id)
			 DO UPDATE SET active_count = global_legendary_count.active_count + 1, updated_at = NOW()`,
			speciesID,
		); err != nil {
			return uuid.Nil, fmt.Errorf("forge: bump global_legendary_count: %w", err)
		}
	}

	// Step 5: destroy source cards
	for _, c := range cards {
		if _, err := exec.Exec(`DELETE FROM player_monsters WHERE id = $1`, c.ID); err != nil {
			return uuid.Nil, fmt.Errorf("forge: delete source %s: %w", c.ID, err)
		}
	}

	// Step 6: insert new player_monsters row.
	newID := uuid.New()
	newVariantID, err := resolveNewVariant(exec, cards[0].SpeciesID, targetRarity, cards[0].Wuxing)
	if err != nil {
		return uuid.Nil, fmt.Errorf("forge: resolve new variant: %w", err)
	}
	if _, err := exec.Exec(
		`INSERT INTO player_monsters (id, player_id, variant_id, lock_state, wuxing_locked, growth_points, is_active)
		 VALUES ($1, $2, $3, 'free', TRUE, 0, TRUE)`,
		newID, playerID, newVariantID,
	); err != nil {
		return uuid.Nil, fmt.Errorf("forge: insert new player_monster: %w", err)
	}

	// Step 7: persist forge_records audit row.
	consumedUUIDs := make([]uuid.UUID, 0, len(cards))
	for _, c := range cards {
		consumedUUIDs = append(consumedUUIDs, c.ID)
	}
	if _, err := exec.Exec(
		`INSERT INTO forge_records (player_id, consumed_ids, target_rarity, writing_chars, succeeded, result_monster_id)
		 VALUES ($1, $2, $3, $4, TRUE, $5)`,
		playerID, pq.Array(consumedUUIDs), string(targetRarity), charsAccumulated, newID,
	); err != nil {
		return uuid.Nil, fmt.Errorf("forge: insert forge_record: %w", err)
	}

	return newID, nil
}

// loadRecipe fetches the static forge_recipes row for the target rarity.
func loadRecipe(exec DBExecutor, target RarityTier) (recipe, error) {
	var r recipe
	err := exec.QueryRow(
		`SELECT source_count, source_rarity, chars_required, extra_material
		 FROM forge_recipes
		 WHERE target_rarity = $1`,
		string(target),
	).Scan(&r.SourceCount, &r.SourceRarity, &r.CharsRequired, &r.ExtraMaterial)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return recipe{}, ErrRecipeNotFound
		}
		return recipe{}, fmt.Errorf("forge: load recipe: %w", err)
	}
	return r, nil
}

// loadSourceCards fetches player_monsters rows joined with variant + species metadata.
// In production this should be performed inside a transaction with SELECT ... FOR UPDATE.
func loadSourceCards(exec DBExecutor, playerID uuid.UUID, ids []uuid.UUID) ([]sourceCardInfo, error) {
	out := make([]sourceCardInfo, 0, len(ids))
	for _, id := range ids {
		var c sourceCardInfo
		err := exec.QueryRow(
			`SELECT pm.id, pm.variant_id, ms.id, mv.wuxing_attr, ms.emotion_tag, mv.rarity, pm.lock_state
			 FROM player_monsters pm
			 JOIN monster_variants mv ON pm.variant_id = mv.id
			 JOIN monster_species ms ON mv.species_id = ms.id
			 WHERE pm.id = $1 AND pm.player_id = $2
			 FOR UPDATE`,
			id, playerID,
		).Scan(&c.ID, &c.VariantID, &c.SpeciesID, &c.Wuxing, &c.EmotionTag, &c.Rarity, &c.LockState)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, fmt.Errorf("forge: source card %s not found for player %s", id, playerID)
			}
			return nil, fmt.Errorf("forge: load source card %s: %w", id, err)
		}
		out = append(out, c)
	}
	return out, nil
}

// resolveNewVariant picks the monster_variants row representing the new forged card.
func resolveNewVariant(exec DBExecutor, speciesID uuid.UUID, target RarityTier, sharedWuxing string) (uuid.UUID, error) {
	var v uuid.UUID
	err := exec.QueryRow(
		`SELECT id FROM monster_variants
		 WHERE species_id = $1 AND rarity = $2 AND wuxing_attr = $3
		 LIMIT 1`,
		speciesID, string(target), sharedWuxing,
	).Scan(&v)
	if err == nil {
		return v, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return uuid.Nil, err
	}
	err = exec.QueryRow(
		`SELECT id FROM monster_variants
		 WHERE species_id = $1 AND rarity = $2
		 LIMIT 1`,
		speciesID, string(target),
	).Scan(&v)
	if err != nil {
		return uuid.Nil, fmt.Errorf("no variant for species=%s rarity=%s: %w", speciesID, target, err)
	}
	return v, nil
}
