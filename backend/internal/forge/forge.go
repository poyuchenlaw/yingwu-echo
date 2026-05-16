// Package forge implements the 應物 ECHO three-tier probability forge system.
//
// Tiers (v0.3 spec §二):
//   L1 Common  : writing >= 50 chars -> 100% success
//   L2 Rare    : 3 same-species common + >= 200 chars + 3 emotion tags -> 30%
//   L3 Legendary: 3 same-species rare + >= 500 chars + 5 active days -> 10%
package forge

import (
	"errors"
	"math/rand"
	"time"
)

// RarityTier mirrors the DB enum.
type RarityTier string

const (
	RarityCommon    RarityTier = "common"
	RarityRare      RarityTier = "rare"
	RarityLegendary RarityTier = "legendary"
)

// ForgeRequest contains all inputs needed to evaluate a forge attempt.
type ForgeRequest struct {
	TargetRarity   RarityTier
	ConsumedIDs    []string // must be exactly 3
	WritingChars   int
	EmotionTagCount int
	ActiveDays     int
}

// ForgeResult is the outcome of a forge attempt.
type ForgeResult struct {
	Succeeded   bool
	Rarity      RarityTier
	RollValue   float64 // for audit / debugging
	FailReason  string
}

var rng = rand.New(rand.NewSource(time.Now().UnixNano()))

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
