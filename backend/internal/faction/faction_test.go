package faction_test

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/simonchen/yingwu-echo/backend/internal/faction"
)

// ============================================================
// Stub plumbing
// ============================================================

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
			*d = v.(int)
		case *float64:
			switch x := v.(type) {
			case float64:
				*d = x
			case int:
				*d = float64(x)
			default:
				return fmt.Errorf("scan[%d]: cannot convert %T to float64", i, v)
			}
		case *string:
			*d = v.(string)
		case *uuid.UUID:
			*d = v.(uuid.UUID)
		case *sql.NullString:
			if v == nil {
				*d = sql.NullString{Valid: false}
			} else {
				*d = sql.NullString{String: v.(string), Valid: true}
			}
		default:
			return fmt.Errorf("scan[%d]: unsupported dest type %T", i, dest[i])
		}
	}
	return nil
}

// scriptedRows wraps a slice of row value-slices for faction.Rows.
type scriptedRows struct {
	rowSets [][]interface{}
	idx     int
	closed  bool
	err     error
}

func (r *scriptedRows) Next() bool {
	if r.idx >= len(r.rowSets) {
		return false
	}
	r.idx++
	return true
}

func (r *scriptedRows) Scan(dest ...interface{}) error {
	if r.idx == 0 || r.idx > len(r.rowSets) {
		return fmt.Errorf("scan called out of sequence")
	}
	values := r.rowSets[r.idx-1]
	row := &scriptedRow{values: values}
	return row.Scan(dest...)
}

func (r *scriptedRows) Close() error { r.closed = true; return nil }
func (r *scriptedRows) Err() error   { return r.err }

type stubExec struct {
	queryRow func(q string, args ...interface{}) faction.RowScanner
	query    func(q string, args ...interface{}) (faction.Rows, error)
}

func (s *stubExec) QueryRow(q string, args ...interface{}) faction.RowScanner {
	return s.queryRow(q, args...)
}
func (s *stubExec) Query(q string, args ...interface{}) (faction.Rows, error) {
	return s.query(q, args...)
}

// ============================================================
// GetFactionByCode tests
// ============================================================

func TestGetFactionByCode_Found(t *testing.T) {
	factionID := uuid.New()
	stub := &stubExec{
		queryRow: func(q string, args ...interface{}) faction.RowScanner {
			if !strings.Contains(q, "player_factions") {
				t.Fatalf("expected player_factions query, got %s", q)
			}
			if args[0] != "deconstructor" {
				t.Fatalf("expected deconstructor arg, got %v", args[0])
			}
			return &scriptedRow{values: []interface{}{
				factionID, "deconstructor", "解構者", "philosophy text",
			}}
		},
	}
	f, err := faction.GetFactionByCode(stub, faction.CodeDeconstructor)
	if err != nil {
		t.Fatal(err)
	}
	if f.ID != factionID || f.Code != faction.CodeDeconstructor || f.NameZh != "解構者" {
		t.Errorf("unexpected faction: %+v", f)
	}
}

func TestGetFactionByCode_NotFound(t *testing.T) {
	stub := &stubExec{
		queryRow: func(q string, args ...interface{}) faction.RowScanner {
			return &scriptedRow{err: sql.ErrNoRows}
		},
	}
	_, err := faction.GetFactionByCode(stub, faction.CodeDeconstructor)
	if !errors.Is(err, faction.ErrFactionNotFound) {
		t.Errorf("expected ErrFactionNotFound, got %v", err)
	}
}

// ============================================================
// ResolveImprintModifiers tests (3 trigger_phase paths)
// ============================================================

func TestResolveImprintModifiers_MirrorWindowOpen(t *testing.T) {
	playerID := uuid.New()
	factionID := uuid.New()

	stub := &stubExec{
		queryRow: func(q string, args ...interface{}) faction.RowScanner {
			if !strings.Contains(q, "player_faction_memberships") {
				t.Fatalf("expected membership query, got %s", q)
			}
			if args[0] != playerID {
				t.Fatalf("expected playerID arg, got %v", args[0])
			}
			return &scriptedRow{values: []interface{}{factionID}}
		},
		query: func(q string, args ...interface{}) (faction.Rows, error) {
			if !strings.Contains(q, "faction_skills") {
				t.Fatalf("expected faction_skills query, got %s", q)
			}
			if args[1] != "mirror_window_open" {
				t.Fatalf("expected mirror_window_open arg, got %v", args[1])
			}
			return &scriptedRows{
				rowSets: [][]interface{}{
					{"deconstructor_trace", 0.05},
				},
			}, nil
		},
	}

	mods, err := faction.ResolveImprintModifiers(stub, playerID, faction.PhaseMirrorWindowOpen)
	if err != nil {
		t.Fatal(err)
	}
	if len(mods) != 1 {
		t.Fatalf("expected 1 modifier, got %d", len(mods))
	}
	if mods[0].Source != "deconstructor_trace" || mods[0].Delta != 0.05 {
		t.Errorf("unexpected modifier: %+v", mods[0])
	}
}

func TestResolveImprintModifiers_ImprintAttempt(t *testing.T) {
	playerID := uuid.New()
	factionID := uuid.New()

	stub := &stubExec{
		queryRow: func(q string, args ...interface{}) faction.RowScanner {
			return &scriptedRow{values: []interface{}{factionID}}
		},
		query: func(q string, args ...interface{}) (faction.Rows, error) {
			if args[1] != "imprint_attempt" {
				t.Fatalf("expected imprint_attempt arg, got %v", args[1])
			}
			// e.g. dreamer at imprint_attempt: dreamer_drift 0.10
			return &scriptedRows{
				rowSets: [][]interface{}{
					{"dreamer_drift", 0.10},
					{"channeler_tear_imprint", 0.10},
				},
			}, nil
		},
	}

	mods, err := faction.ResolveImprintModifiers(stub, playerID, faction.PhaseImprintAttempt)
	if err != nil {
		t.Fatal(err)
	}
	if len(mods) != 2 {
		t.Fatalf("expected 2 modifiers, got %d", len(mods))
	}
}

func TestResolveImprintModifiers_DamageResolve(t *testing.T) {
	playerID := uuid.New()
	factionID := uuid.New()

	stub := &stubExec{
		queryRow: func(q string, args ...interface{}) faction.RowScanner {
			return &scriptedRow{values: []interface{}{factionID}}
		},
		query: func(q string, args ...interface{}) (faction.Rows, error) {
			if args[1] != "damage_resolve" {
				t.Fatalf("expected damage_resolve arg, got %v", args[1])
			}
			return &scriptedRows{
				rowSets: [][]interface{}{
					{"tuner_chord", 0.00},
					{"observer_triangulate", 0.08},
				},
			}, nil
		},
	}

	mods, err := faction.ResolveImprintModifiers(stub, playerID, faction.PhaseDamageResolve)
	if err != nil {
		t.Fatal(err)
	}
	if len(mods) != 2 {
		t.Fatalf("expected 2 modifiers, got %d", len(mods))
	}
}

func TestResolveImprintModifiers_NoMembership(t *testing.T) {
	playerID := uuid.New()
	stub := &stubExec{
		queryRow: func(q string, args ...interface{}) faction.RowScanner {
			return &scriptedRow{err: sql.ErrNoRows}
		},
		query: func(q string, args ...interface{}) (faction.Rows, error) {
			t.Fatal("query should not fire when no membership")
			return nil, nil
		},
	}
	mods, err := faction.ResolveImprintModifiers(stub, playerID, faction.PhaseMirrorWindowOpen)
	if err != nil {
		t.Fatal(err)
	}
	if len(mods) != 0 {
		t.Errorf("expected empty modifiers, got %d", len(mods))
	}
}

// ============================================================
// GetSkillsForFaction
// ============================================================

func TestGetSkillsForFaction(t *testing.T) {
	factionID := uuid.New()
	skill1ID := uuid.New()
	skill2ID := uuid.New()

	stub := &stubExec{
		query: func(q string, args ...interface{}) (faction.Rows, error) {
			if !strings.Contains(q, "faction_skills") {
				t.Fatalf("expected faction_skills query, got %s", q)
			}
			if args[0] != factionID {
				t.Fatalf("expected factionID arg, got %v", args[0])
			}
			return &scriptedRows{
				rowSets: [][]interface{}{
					{skill1ID, factionID, "deconstructor_anatomize", "深層解剖", 0.03, "damage_resolve", "desc"},
					{skill2ID, factionID, "deconstructor_split", "語義切分", 0.07, "imprint_attempt", "desc"},
				},
			}, nil
		},
	}

	skills, err := faction.GetSkillsForFaction(stub, factionID)
	if err != nil {
		t.Fatal(err)
	}
	if len(skills) != 2 {
		t.Fatalf("expected 2 skills, got %d", len(skills))
	}
	if skills[0].SkillCode != "deconstructor_anatomize" {
		t.Errorf("unexpected first skill: %+v", skills[0])
	}
	if skills[1].TriggerPhase != faction.PhaseImprintAttempt {
		t.Errorf("unexpected second skill trigger: %+v", skills[1])
	}
}
