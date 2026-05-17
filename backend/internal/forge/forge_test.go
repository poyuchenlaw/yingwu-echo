package forge_test

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/simonchen/yingwu-echo/backend/internal/forge"
)

// ============================================================
// v0.3 legacy tests (db=nil path) — must stay green
// ============================================================

func TestCommonForge_Success(t *testing.T) {
	req := forge.ForgeRequest{TargetRarity: forge.RarityCommon, WritingChars: 60}
	res, err := forge.Attempt(req)
	if err != nil {
		t.Fatal(err)
	}
	if !res.Succeeded {
		t.Errorf("common forge with 60 chars should succeed, got: %s", res.FailReason)
	}
}

func TestCommonForge_Fail(t *testing.T) {
	req := forge.ForgeRequest{TargetRarity: forge.RarityCommon, WritingChars: 30}
	res, err := forge.Attempt(req)
	if err != nil {
		t.Fatal(err)
	}
	if res.Succeeded {
		t.Error("common forge with 30 chars should fail")
	}
}

func TestRareForge_MissingEmotions(t *testing.T) {
	req := forge.ForgeRequest{
		TargetRarity:    forge.RarityRare,
		ConsumedIDs:     []string{"a", "b", "c"},
		WritingChars:    250,
		EmotionTagCount: 1, // not enough
	}
	res, err := forge.Attempt(req)
	if err != nil {
		t.Fatal(err)
	}
	if res.Succeeded {
		t.Error("rare forge with only 1 emotion tag should fail gate check")
	}
}

func TestLegendaryForge_InsufficientActiveDays(t *testing.T) {
	req := forge.ForgeRequest{
		TargetRarity: forge.RarityLegendary,
		ConsumedIDs:  []string{"a", "b", "c"},
		WritingChars: 600,
		ActiveDays:   3, // need 5
	}
	res, err := forge.Attempt(req)
	if err != nil {
		t.Fatal(err)
	}
	if res.Succeeded {
		t.Error("legendary forge with 3 active days should fail gate check")
	}
}

// ============================================================
// v0.4 TryForge tests — DB-backed via stub
// ============================================================

// stubResult is a no-op sql.Result.
type stubResult struct{}

func (stubResult) LastInsertId() (int64, error) { return 0, nil }
func (stubResult) RowsAffected() (int64, error) { return 1, nil }

// scriptedRow returns predetermined values for Scan.
type scriptedRow struct {
	values []interface{}
	err    error
}

func (r *scriptedRow) Scan(dest ...interface{}) error {
	if r.err != nil {
		return r.err
	}
	if len(dest) != len(r.values) {
		return fmt.Errorf("scan: expected %d dest, got %d", len(r.values), len(dest))
	}
	for i, v := range r.values {
		switch d := dest[i].(type) {
		case *int:
			x, ok := v.(int)
			if !ok {
				return fmt.Errorf("scan[%d]: expected int, got %T", i, v)
			}
			*d = x
		case *string:
			x, ok := v.(string)
			if !ok {
				return fmt.Errorf("scan[%d]: expected string, got %T", i, v)
			}
			*d = x
		case *uuid.UUID:
			x, ok := v.(uuid.UUID)
			if !ok {
				return fmt.Errorf("scan[%d]: expected uuid.UUID, got %T", i, v)
			}
			*d = x
		case *sql.NullString:
			if v == nil {
				*d = sql.NullString{Valid: false}
			} else if s, ok := v.(string); ok {
				*d = sql.NullString{String: s, Valid: true}
			} else {
				return fmt.Errorf("scan[%d]: expected string or nil, got %T", i, v)
			}
		default:
			return fmt.Errorf("scan[%d]: unsupported dest type %T", i, dest[i])
		}
	}
	return nil
}

// stubExec implements forge.DBExecutor with a scripted query/exec log.
// Tests register expected query substrings; queries are matched in registration order
// (FIFO) and may also be matched by exact substring (round-robin within a substring slot).
type stubExec struct {
	t            *testing.T
	queryHandler func(query string, args ...interface{}) forge.RowScanner
	execHandler  func(query string, args ...interface{}) (sql.Result, error)
}

func (s *stubExec) QueryRow(q string, args ...interface{}) forge.RowScanner {
	return s.queryHandler(q, args...)
}
func (s *stubExec) Exec(q string, args ...interface{}) (sql.Result, error) {
	return s.execHandler(q, args...)
}

// helper: rare-recipe row values matching forge.loadRecipe Scan order.
func rareRecipeRow() *scriptedRow {
	// source_count, source_rarity, chars_required, extra_material
	return &scriptedRow{values: []interface{}{3, "common", 500, nil}}
}

func legendaryRecipeRow() *scriptedRow {
	return &scriptedRow{values: []interface{}{3, "rare", 2000, `{"type":"shard"}`}}
}

// cardRow returns a scriptedRow matching loadSourceCards Scan order:
// id, variant_id, species_id, wuxing, emotion_tag, rarity, lock_state
func cardRow(id, variantID, speciesID uuid.UUID, wuxing, emotion, rarity, lock string) *scriptedRow {
	return &scriptedRow{values: []interface{}{id, variantID, speciesID, wuxing, emotion, rarity, lock}}
}

func TestTryForge_RareSuccess(t *testing.T) {
	playerID := uuid.New()
	speciesID := uuid.New()
	variantSrc := uuid.New()
	variantDst := uuid.New()
	c1, c2, c3 := uuid.New(), uuid.New(), uuid.New()

	var insertedPlayerMonster, insertedForgeRecord bool

	stub := &stubExec{t: t}
	rows := []*scriptedRow{
		rareRecipeRow(),
		cardRow(c1, variantSrc, speciesID, "metal", "joy", "common", "free"),
		cardRow(c2, variantSrc, speciesID, "metal", "joy", "common", "free"),
		cardRow(c3, variantSrc, speciesID, "metal", "joy", "common", "free"),
		{values: []interface{}{variantDst}}, // resolveNewVariant exact match
	}
	rowIdx := 0
	stub.queryHandler = func(q string, args ...interface{}) forge.RowScanner {
		if rowIdx >= len(rows) {
			t.Fatalf("unexpected query #%d: %s", rowIdx, q)
		}
		r := rows[rowIdx]
		rowIdx++
		return r
	}
	stub.execHandler = func(q string, args ...interface{}) (sql.Result, error) {
		switch {
		case strings.Contains(q, "DELETE FROM player_monsters"):
			return stubResult{}, nil
		case strings.Contains(q, "INSERT INTO player_monsters"):
			insertedPlayerMonster = true
			return stubResult{}, nil
		case strings.Contains(q, "INSERT INTO forge_records"):
			insertedForgeRecord = true
			return stubResult{}, nil
		}
		return nil, fmt.Errorf("unexpected exec: %s", q)
	}

	newID, err := forge.TryForge(stub, playerID, []uuid.UUID{c1, c2, c3}, forge.RarityRare, 500)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if newID == uuid.Nil {
		t.Fatal("expected non-nil newID")
	}
	if !insertedPlayerMonster {
		t.Error("expected INSERT INTO player_monsters")
	}
	if !insertedForgeRecord {
		t.Error("expected INSERT INTO forge_records")
	}
}

func TestTryForge_LegendaryCapReached(t *testing.T) {
	playerID := uuid.New()
	speciesID := uuid.New()
	variantSrc := uuid.New()
	c1, c2, c3 := uuid.New(), uuid.New(), uuid.New()

	stub := &stubExec{t: t}
	rows := []*scriptedRow{
		legendaryRecipeRow(),
		cardRow(c1, variantSrc, speciesID, "metal", "anger", "rare", "free"),
		cardRow(c2, variantSrc, speciesID, "wood", "anger", "rare", "free"),
		cardRow(c3, variantSrc, speciesID, "fire", "anger", "rare", "free"),
		{values: []interface{}{99}}, // global_legendary_count active_count
	}
	rowIdx := 0
	stub.queryHandler = func(q string, args ...interface{}) forge.RowScanner {
		if rowIdx >= len(rows) {
			t.Fatalf("unexpected query #%d: %s", rowIdx, q)
		}
		r := rows[rowIdx]
		rowIdx++
		return r
	}
	stub.execHandler = func(q string, args ...interface{}) (sql.Result, error) {
		return nil, fmt.Errorf("no exec should fire when cap reached: %s", q)
	}

	_, err := forge.TryForge(stub, playerID, []uuid.UUID{c1, c2, c3}, forge.RarityLegendary, 2000)
	if !errors.Is(err, forge.ErrLegendaryCapReached) {
		t.Fatalf("expected ErrLegendaryCapReached, got %v", err)
	}
}

func TestTryForge_InsufficientChars(t *testing.T) {
	playerID := uuid.New()
	speciesID := uuid.New()
	variantSrc := uuid.New()
	c1, c2, c3 := uuid.New(), uuid.New(), uuid.New()

	stub := &stubExec{t: t}
	rows := []*scriptedRow{
		rareRecipeRow(),
		cardRow(c1, variantSrc, speciesID, "metal", "joy", "common", "free"),
		cardRow(c2, variantSrc, speciesID, "metal", "joy", "common", "free"),
		cardRow(c3, variantSrc, speciesID, "metal", "joy", "common", "free"),
	}
	rowIdx := 0
	stub.queryHandler = func(q string, args ...interface{}) forge.RowScanner {
		if rowIdx >= len(rows) {
			t.Fatalf("unexpected query #%d: %s", rowIdx, q)
		}
		r := rows[rowIdx]
		rowIdx++
		return r
	}
	stub.execHandler = func(q string, args ...interface{}) (sql.Result, error) {
		return nil, fmt.Errorf("no exec should fire when chars insufficient: %s", q)
	}

	_, err := forge.TryForge(stub, playerID, []uuid.UUID{c1, c2, c3}, forge.RarityRare, 499)
	if !errors.Is(err, forge.ErrCharsBelowRequired) {
		t.Fatalf("expected ErrCharsBelowRequired, got %v", err)
	}
}

func TestTryForge_EmotionMismatch(t *testing.T) {
	playerID := uuid.New()
	speciesID := uuid.New()
	variantSrc := uuid.New()
	c1, c2, c3 := uuid.New(), uuid.New(), uuid.New()

	stub := &stubExec{t: t}
	rows := []*scriptedRow{
		rareRecipeRow(),
		cardRow(c1, variantSrc, speciesID, "metal", "joy", "common", "free"),
		cardRow(c2, variantSrc, speciesID, "metal", "anger", "common", "free"), // different emotion
		cardRow(c3, variantSrc, speciesID, "metal", "joy", "common", "free"),
	}
	rowIdx := 0
	stub.queryHandler = func(q string, args ...interface{}) forge.RowScanner {
		if rowIdx >= len(rows) {
			t.Fatalf("unexpected query #%d: %s", rowIdx, q)
		}
		r := rows[rowIdx]
		rowIdx++
		return r
	}
	stub.execHandler = func(q string, args ...interface{}) (sql.Result, error) {
		return nil, fmt.Errorf("no exec should fire when emotions mismatch: %s", q)
	}

	_, err := forge.TryForge(stub, playerID, []uuid.UUID{c1, c2, c3}, forge.RarityRare, 500)
	if !errors.Is(err, forge.ErrEmotionMismatch) {
		t.Fatalf("expected ErrEmotionMismatch, got %v", err)
	}
}

func TestTryForge_WuxingMismatchOnRare(t *testing.T) {
	playerID := uuid.New()
	speciesID := uuid.New()
	variantSrc := uuid.New()
	c1, c2, c3 := uuid.New(), uuid.New(), uuid.New()

	stub := &stubExec{t: t}
	rows := []*scriptedRow{
		rareRecipeRow(),
		cardRow(c1, variantSrc, speciesID, "metal", "joy", "common", "free"),
		cardRow(c2, variantSrc, speciesID, "wood", "joy", "common", "free"), // different wuxing
		cardRow(c3, variantSrc, speciesID, "metal", "joy", "common", "free"),
	}
	rowIdx := 0
	stub.queryHandler = func(q string, args ...interface{}) forge.RowScanner {
		if rowIdx >= len(rows) {
			t.Fatalf("unexpected query #%d: %s", rowIdx, q)
		}
		r := rows[rowIdx]
		rowIdx++
		return r
	}
	stub.execHandler = func(q string, args ...interface{}) (sql.Result, error) {
		return nil, fmt.Errorf("no exec should fire when wuxing mismatch: %s", q)
	}

	_, err := forge.TryForge(stub, playerID, []uuid.UUID{c1, c2, c3}, forge.RarityRare, 500)
	if !errors.Is(err, forge.ErrWuxingMismatch) {
		t.Fatalf("expected ErrWuxingMismatch, got %v", err)
	}
}

func TestTryForge_SourceNotFree(t *testing.T) {
	playerID := uuid.New()
	speciesID := uuid.New()
	variantSrc := uuid.New()
	c1, c2, c3 := uuid.New(), uuid.New(), uuid.New()

	stub := &stubExec{t: t}
	rows := []*scriptedRow{
		rareRecipeRow(),
		cardRow(c1, variantSrc, speciesID, "metal", "joy", "common", "in_battle"), // locked
		cardRow(c2, variantSrc, speciesID, "metal", "joy", "common", "free"),
		cardRow(c3, variantSrc, speciesID, "metal", "joy", "common", "free"),
	}
	rowIdx := 0
	stub.queryHandler = func(q string, args ...interface{}) forge.RowScanner {
		if rowIdx >= len(rows) {
			t.Fatalf("unexpected query #%d: %s", rowIdx, q)
		}
		r := rows[rowIdx]
		rowIdx++
		return r
	}
	stub.execHandler = func(q string, args ...interface{}) (sql.Result, error) {
		return nil, fmt.Errorf("no exec should fire when source locked: %s", q)
	}

	_, err := forge.TryForge(stub, playerID, []uuid.UUID{c1, c2, c3}, forge.RarityRare, 500)
	if !errors.Is(err, forge.ErrSourceNotFree) {
		t.Fatalf("expected ErrSourceNotFree, got %v", err)
	}
}

func TestTryForge_NilExecRejected(t *testing.T) {
	_, err := forge.TryForge(nil, uuid.New(), []uuid.UUID{uuid.New()}, forge.RarityRare, 500)
	if err == nil {
		t.Fatal("expected error when exec=nil, got nil")
	}
}
