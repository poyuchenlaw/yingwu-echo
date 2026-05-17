// Package battle implements the 應物 ECHO battle state machine.
//
// State transitions:
//
//	IDLE -> SUMMONED -> MIRROR_WINDOW_OPEN -> CAPTURED
//	                                       -> RETURNED_TO_OWNER
//
// Key mechanics (v0.3 spec §三/§四):
//   - 五行剋制 matrix: x1.35 attacker / x0.85 defender
//   - 永久映刻 (permanent imprint): captured monster written to player_monsters
//   - 落後反轉 (reverse gambit): HP < 30% triggers second imprint window
package battle

import (
	"errors"
	"math/rand"
	"time"

	"github.com/google/uuid"
)

// BattleState represents the state machine states.
type BattleState string

const (
	StateIdle             BattleState = "idle"
	StateSummoned         BattleState = "summoned"
	StateMirrorWindowOpen BattleState = "mirror_window_open"
	StateCaptured         BattleState = "captured"
	StateReturnedToOwner  BattleState = "returned_to_owner"
)

// Wuxing represents the five-element attribute.
type Wuxing string

const (
	WuxingMetal Wuxing = "metal"
	WuxingWood  Wuxing = "wood"
	WuxingWater Wuxing = "water"
	WuxingFire  Wuxing = "fire"
	WuxingEarth Wuxing = "earth"
)

// WuxingMatrix defines the 克制 (counter) relationships.
// Key counters Value (attacker Key -> defender Value gets x1.35 / x0.85).
var WuxingMatrix = map[Wuxing]Wuxing{
	WuxingMetal: WuxingWood,  // 金剋木
	WuxingWood:  WuxingEarth, // 木剋土
	WuxingWater: WuxingFire,  // 水剋火
	WuxingFire:  WuxingMetal, // 火剋金
	WuxingEarth: WuxingWater, // 土剋水
}

const (
	CounterMultiplierAttack  = 1.35 // attacker bonus when countering
	CounterMultiplierDefense = 0.85 // defender penalty when countered
	ReverseGambitHPThreshold = 0.30 // HP fraction that triggers second imprint window
)

// Monster is a minimal in-memory representation for battle calculation.
// Full persistence is handled by the db layer.
type Monster struct {
	ID        uuid.UUID
	OwnerID   uuid.UUID
	Wuxing    Wuxing
	PowerBase int
	MaxHP     int
	CurrentHP int
}

// BattleSession holds the live state of a single battle.
type BattleSession struct {
	ID               uuid.UUID
	Attacker         *Monster
	Defender         *Monster
	State            BattleState
	ReverseTriggered bool
	StartedAt        time.Time
	rng              *rand.Rand
}

// NewSession initialises a battle session.
func NewSession(attacker, defender *Monster) (*BattleSession, error) {
	if attacker == nil || defender == nil {
		return nil, errors.New("battle: attacker and defender must not be nil")
	}
	return &BattleSession{
		ID:        uuid.New(),
		Attacker:  attacker,
		Defender:  defender,
		State:     StateIdle,
		StartedAt: time.Now().UTC(),
		rng:       rand.New(rand.NewSource(time.Now().UnixNano())),
	}, nil
}

// Summon transitions from IDLE to SUMMONED.
func (s *BattleSession) Summon() error {
	if s.State != StateIdle {
		return errors.New("battle: can only summon from idle state")
	}
	s.State = StateSummoned
	return nil
}

// OpenMirrorWindow transitions to MIRROR_WINDOW_OPEN where imprinting can occur.
func (s *BattleSession) OpenMirrorWindow() error {
	if s.State != StateSummoned {
		return errors.New("battle: mirror window requires summoned state")
	}
	s.State = StateMirrorWindowOpen
	return nil
}

// DamageMultiplier returns the effective damage multiplier for an attack.
// (attacker's wuxing vs defender's wuxing)
func DamageMultiplier(attacker, defender Wuxing) float64 {
	if countered, ok := WuxingMatrix[attacker]; ok && countered == defender {
		return CounterMultiplierAttack
	}
	// Check if defender counters attacker (defender benefits from x0.85 received)
	if countered, ok := WuxingMatrix[defender]; ok && countered == attacker {
		return CounterMultiplierDefense
	}
	return 1.0 // neutral
}

// CalculateDamage computes damage for one hit.
// baseDamage is the raw power value from the attacker.
func CalculateDamage(attacker, defender *Monster, baseDamage int) int {
	mult := DamageMultiplier(attacker.Wuxing, defender.Wuxing)
	return int(float64(baseDamage) * mult)
}

// TryImprint attempts permanent imprint of the defender.
// Returns true if imprint succeeds (mirror window open + optional skill check).
// Permanent imprint: captured monster ownership transfers; it does NOT return.
func (s *BattleSession) TryImprint() (bool, error) {
	if s.State != StateMirrorWindowOpen {
		return false, errors.New("battle: imprint requires mirror window open state")
	}
	// TODO: caller should pass real rarity and modifiers from battle context
	prob := ImprintProbability(RarityCommon, nil)
	success := s.rng.Float64() < prob
	if success {
		s.State = StateCaptured
		// Caller must write player_monsters row with imprinted_from_player_id set
	}
	return success, nil
}

// CheckReverseGambit evaluates whether HP < 30% triggers the reverse gambit.
// If triggered and not yet used, opens a second mirror window.
func (s *BattleSession) CheckReverseGambit() bool {
	if s.ReverseTriggered {
		return false // can only trigger once per battle
	}
	defenderHPFraction := float64(s.Defender.CurrentHP) / float64(s.Defender.MaxHP)
	if defenderHPFraction < ReverseGambitHPThreshold {
		s.ReverseTriggered = true
		s.State = StateMirrorWindowOpen
		return true
	}
	return false
}

// ReturnToOwner ends the battle without imprint.
func (s *BattleSession) ReturnToOwner() error {
	if s.State == StateCaptured {
		return errors.New("battle: already captured, cannot return to owner")
	}
	s.State = StateReturnedToOwner
	return nil
}
