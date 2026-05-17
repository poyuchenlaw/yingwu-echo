// Package battle - imprint probability engine (v0.3.6 patch).
package battle

// Rarity is the target monster rarity for imprint probability calculation.
type Rarity string

const (
	RarityCommon  Rarity = "common"
	RarityRefined Rarity = "refined"
	RarityDivine  Rarity = "divine"
)

// ImprintModifier is an additive bonus applied to imprint probability.
type ImprintModifier struct {
	Source string
	Delta  float64
}

// Faction skill modifier constructors.
func ModDeconstructorTrace() ImprintModifier {
	return ImprintModifier{Source: "deconstructor_trace", Delta: 0.05}
}
func ModChannelerTearImprint() ImprintModifier {
	return ImprintModifier{Source: "channeler_tear_imprint", Delta: 0.10}
}
func ModObserverMark() ImprintModifier { return ImprintModifier{Source: "observer_mark", Delta: 0.15} }
func ModTunerChord() ImprintModifier   { return ImprintModifier{Source: "tuner_chord", Delta: 0.00} }
func ModDreamerDissolve() ImprintModifier {
	return ImprintModifier{Source: "dreamer_dissolve", Delta: 0.20}
}
func ModReverseGambit() ImprintModifier {
	return ImprintModifier{Source: "reverse_gambit", Delta: 0.20}
}

const (
	imprintProbMin = 0.05
	imprintProbMax = 0.90
)

var baseImprintProbability = map[Rarity]float64{
	RarityCommon:  0.80,
	RarityRefined: 0.50,
	RarityDivine:  0.25,
}

// ImprintProbability computes the final clamped imprint probability.
// Sums base probability + all modifier Deltas, then clamps to [0.05, 0.90].
func ImprintProbability(target Rarity, modifiers []ImprintModifier) float64 {
	base, ok := baseImprintProbability[target]
	if !ok {
		base = imprintProbMin
	}
	total := base
	for _, m := range modifiers {
		total += m.Delta
	}
	if total < imprintProbMin {
		total = imprintProbMin
	}
	if total > imprintProbMax {
		total = imprintProbMax
	}
	return total
}
