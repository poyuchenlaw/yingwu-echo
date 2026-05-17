package battle_test

import (
	"testing"

	"github.com/simonchen/yingwu-echo/backend/internal/battle"
)

func TestImprintProbability_BaseCommon(t *testing.T) {
	got := battle.ImprintProbability(battle.RarityCommon, nil)
	if got != 0.80 {
		t.Errorf("expected 0.80, got %f", got)
	}
}

func TestImprintProbability_BaseRare(t *testing.T) {
	got := battle.ImprintProbability(battle.RarityRare, nil)
	if got != 0.50 {
		t.Errorf("expected 0.50, got %f", got)
	}
}

func TestImprintProbability_BaseLegendary(t *testing.T) {
	got := battle.ImprintProbability(battle.RarityLegendary, nil)
	if got != 0.25 {
		t.Errorf("expected 0.25, got %f", got)
	}
}

func TestImprintProbability_FactionStack(t *testing.T) {
	mods := []battle.ImprintModifier{
		battle.ModChannelerTearImprint(),
		battle.ModObserverMark(),
	}
	got := battle.ImprintProbability(battle.RarityRare, mods)
	// 0.50 + 0.10 + 0.15 = 0.75
	if got != 0.75 {
		t.Errorf("expected 0.75, got %f", got)
	}
}

func TestImprintProbability_ReverseGambitHitsMax(t *testing.T) {
	mods := []battle.ImprintModifier{battle.ModReverseGambit()}
	got := battle.ImprintProbability(battle.RarityCommon, mods)
	// 0.80 + 0.20 = 1.00, clamped to 0.90
	if got != 0.90 {
		t.Errorf("expected 0.90 (clamped), got %f", got)
	}
}

func TestImprintProbability_ClampMax(t *testing.T) {
	mods := []battle.ImprintModifier{{Source: "big", Delta: 0.50}}
	got := battle.ImprintProbability(battle.RarityCommon, mods)
	// 0.80 + 0.50 = 1.30, clamped to 0.90
	if got != 0.90 {
		t.Errorf("expected 0.90 (clamped), got %f", got)
	}
}

func TestImprintProbability_ClampMin(t *testing.T) {
	mods := []battle.ImprintModifier{{Source: "neg", Delta: -1.0}}
	got := battle.ImprintProbability(battle.RarityLegendary, mods)
	// 0.25 - 1.0 = -0.75, clamped to 0.05
	if got != 0.05 {
		t.Errorf("expected 0.05 (clamped), got %f", got)
	}
}

func TestTryImprint_UsesRNG(t *testing.T) {
	successes := 0
	for i := 0; i < 200; i++ {
		a := &battle.Monster{Wuxing: battle.WuxingMetal, MaxHP: 100, CurrentHP: 100, PowerBase: 5}
		d := &battle.Monster{Wuxing: battle.WuxingWood, MaxHP: 100, CurrentHP: 100, PowerBase: 5}
		s, _ := battle.NewSession(a, d)
		_ = s.Summon()
		_ = s.OpenMirrorWindow()
		ok, _ := s.TryImprint(nil)
		if ok {
			successes++
		}
	}
	// base prob 0.80 on 200 trials; expect roughly 160 successes
	// assert at least 100 and at most 200 (very loose for CI stability)
	if successes < 100 || successes > 200 {
		t.Errorf("expected 100-200 successes in 200 trials with p=0.80, got %d", successes)
	}
}
