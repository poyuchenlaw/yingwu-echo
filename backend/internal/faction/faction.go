// Package faction implements the 應物 ECHO five-faction system (v0.4).
//
// Each player belongs to one of 5 factions, each with 3 skills (15 skills total).
// Skills carry an imprint_delta and a trigger_phase. During battle, the engine
// resolves all skills whose trigger_phase matches the current phase into
// battle.ImprintModifier values, which sum into the imprint probability formula.
//
// See migrations/0002_v04_rarity_factions_lock.sql §B1/B2 and
// data/seed/0002_factions.sql for the canonical data.
package faction

import "github.com/google/uuid"

// FactionCode mirrors player_factions.faction_code (UNIQUE).
type FactionCode string

const (
	CodeDeconstructor FactionCode = "deconstructor" // 解構者
	CodeChanneler     FactionCode = "channeler"     // 引流人
	CodeObserver      FactionCode = "observer"      // 觀測使
	CodeTuner         FactionCode = "tuner"         // 調律師
	CodeDreamer       FactionCode = "dreamer"       // 築夢匠
)

// AllCodes lists the canonical 5 faction codes (deterministic ordering).
var AllCodes = []FactionCode{
	CodeDeconstructor,
	CodeChanneler,
	CodeObserver,
	CodeTuner,
	CodeDreamer,
}

// TriggerPhase mirrors faction_skills.trigger_phase.
// These values must align with battle.BattleState transitions and damage
// resolution callbacks so the engine can call ResolveImprintModifiers at the
// correct moment.
type TriggerPhase string

const (
	PhaseSummoned          TriggerPhase = "summoned"
	PhaseMirrorWindowOpen  TriggerPhase = "mirror_window_open"
	PhaseImprintAttempt    TriggerPhase = "imprint_attempt"
	PhaseDamageResolve     TriggerPhase = "damage_resolve"
)

// Faction is the in-memory representation of a player_factions row.
type Faction struct {
	ID         uuid.UUID
	Code       FactionCode
	NameZh     string
	Philosophy string
}

// Skill is the in-memory representation of a faction_skills row.
type Skill struct {
	ID            uuid.UUID
	FactionID     uuid.UUID
	SkillCode     string
	NameZh        string
	ImprintDelta  float64
	TriggerPhase  TriggerPhase
	Description   string
}
