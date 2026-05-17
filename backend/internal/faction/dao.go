// DAO for faction module. Reads from player_factions, faction_skills, and
// joins through a player→faction membership table.
//
// NOTE: the v0.4 migration creates player_factions (master) and faction_skills
// but does not yet create the player_id -> faction_id join table; we model
// that as `player_faction_memberships(player_id UUID PRIMARY KEY, faction_id UUID)`
// which a future migration will add. For now ResolveImprintModifiers accepts
// an explicit faction lookup callback so callers can stub the join.
package faction

import (
	"database/sql"
	"errors"
	"fmt"

	"github.com/google/uuid"

	"github.com/simonchen/yingwu-echo/backend/internal/battle"
)

// DBExecutor is the narrow surface used by DAO operations.
// Production code passes *sql.DB via WrapDB; tests pass a stub.
type DBExecutor interface {
	QueryRow(query string, args ...interface{}) RowScanner
	Query(query string, args ...interface{}) (Rows, error)
}

// RowScanner mirrors *sql.Row.Scan.
type RowScanner interface {
	Scan(dest ...interface{}) error
}

// Rows is the minimal surface of *sql.Rows we need.
type Rows interface {
	Next() bool
	Scan(dest ...interface{}) error
	Close() error
	Err() error
}

// sqlDBAdapter wraps *sql.DB.
type sqlDBAdapter struct{ db *sql.DB }

func (a *sqlDBAdapter) QueryRow(q string, args ...interface{}) RowScanner {
	return a.db.QueryRow(q, args...)
}
func (a *sqlDBAdapter) Query(q string, args ...interface{}) (Rows, error) {
	r, err := a.db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	return r, nil
}

// WrapDB returns a DBExecutor backed by a real *sql.DB.
func WrapDB(db *sql.DB) DBExecutor {
	if db == nil {
		return nil
	}
	return &sqlDBAdapter{db: db}
}

// ErrFactionNotFound is returned when no row matches the requested code/id.
var ErrFactionNotFound = errors.New("faction: not found")

// GetFactionByCode loads one faction by its canonical code.
func GetFactionByCode(exec DBExecutor, code FactionCode) (Faction, error) {
	var f Faction
	var codeStr string
	err := exec.QueryRow(
		`SELECT id, faction_code, name_zh, COALESCE(philosophy, '')
		 FROM player_factions WHERE faction_code = $1`,
		string(code),
	).Scan(&f.ID, &codeStr, &f.NameZh, &f.Philosophy)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Faction{}, ErrFactionNotFound
		}
		return Faction{}, fmt.Errorf("faction: load by code: %w", err)
	}
	f.Code = FactionCode(codeStr)
	return f, nil
}

// GetSkillsForFaction loads all faction_skills rows for one faction.
// Returns skills in stable insertion order (DB default).
func GetSkillsForFaction(exec DBExecutor, factionID uuid.UUID) ([]Skill, error) {
	rows, err := exec.Query(
		`SELECT id, faction_id, skill_code, name_zh,
		        imprint_delta, COALESCE(trigger_phase, ''), COALESCE(description, '')
		 FROM faction_skills
		 WHERE faction_id = $1
		 ORDER BY skill_code`,
		factionID,
	)
	if err != nil {
		return nil, fmt.Errorf("faction: load skills: %w", err)
	}
	defer rows.Close()

	var out []Skill
	for rows.Next() {
		var s Skill
		var trigger string
		if err := rows.Scan(&s.ID, &s.FactionID, &s.SkillCode, &s.NameZh,
			&s.ImprintDelta, &trigger, &s.Description); err != nil {
			return nil, fmt.Errorf("faction: scan skill: %w", err)
		}
		s.TriggerPhase = TriggerPhase(trigger)
		out = append(out, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("faction: rows err: %w", err)
	}
	return out, nil
}

// ResolveImprintModifiers loads the player's faction and returns all skill
// modifiers whose trigger_phase matches the requested phase, as a slice of
// battle.ImprintModifier ready to feed into battle.ImprintProbability.
//
// Lookup chain:
//  1. SELECT faction_id FROM player_faction_memberships WHERE player_id = $1
//  2. SELECT * FROM faction_skills WHERE faction_id = $X AND trigger_phase = $phase
//
// If the player has no faction membership row, returns an empty slice (no error).
func ResolveImprintModifiers(
	exec DBExecutor,
	playerID uuid.UUID,
	phase TriggerPhase,
) ([]battle.ImprintModifier, error) {
	var factionID uuid.UUID
	err := exec.QueryRow(
		`SELECT faction_id FROM player_faction_memberships WHERE player_id = $1`,
		playerID,
	).Scan(&factionID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("faction: load membership: %w", err)
	}

	rows, err := exec.Query(
		`SELECT skill_code, imprint_delta
		 FROM faction_skills
		 WHERE faction_id = $1 AND trigger_phase = $2
		 ORDER BY skill_code`,
		factionID, string(phase),
	)
	if err != nil {
		return nil, fmt.Errorf("faction: load phase skills: %w", err)
	}
	defer rows.Close()

	var mods []battle.ImprintModifier
	for rows.Next() {
		var code string
		var delta float64
		if err := rows.Scan(&code, &delta); err != nil {
			return nil, fmt.Errorf("faction: scan phase skill: %w", err)
		}
		mods = append(mods, battle.ImprintModifier{Source: code, Delta: delta})
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("faction: phase rows err: %w", err)
	}
	return mods, nil
}
