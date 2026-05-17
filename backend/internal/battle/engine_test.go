package battle_test

import (
	"testing"

	"github.com/google/uuid"
	"github.com/simonchen/yingwu-echo/backend/internal/battle"
)

func newMonster(w battle.Wuxing, hp int) *battle.Monster {
	return &battle.Monster{
		ID:        uuid.New(),
		OwnerID:   uuid.New(),
		Wuxing:    w,
		PowerBase: 5,
		MaxHP:     hp,
		CurrentHP: hp,
	}
}

func TestDamageMultiplier_Counter(t *testing.T) {
	// 金剋木: attacker Metal, defender Wood -> x1.35
	mult := battle.DamageMultiplier(battle.WuxingMetal, battle.WuxingWood)
	if mult != battle.CounterMultiplierAttack {
		t.Errorf("expected %.2f, got %.2f", battle.CounterMultiplierAttack, mult)
	}
}

func TestDamageMultiplier_Countered(t *testing.T) {
	// 木剋金: attacker Wood, defender Metal -> defender perspective x0.85
	mult := battle.DamageMultiplier(battle.WuxingWood, battle.WuxingMetal)
	if mult != battle.CounterMultiplierDefense {
		t.Errorf("expected %.2f, got %.2f", battle.CounterMultiplierDefense, mult)
	}
}

func TestDamageMultiplier_Neutral(t *testing.T) {
	// Metal vs Earth: Metal counters Wood, Wood counters Earth, Earth counters Water.
	// Metal does NOT counter Earth, Earth does NOT counter Metal -> neutral.
	mult := battle.DamageMultiplier(battle.WuxingMetal, battle.WuxingEarth)
	if mult != 1.0 {
		t.Errorf("expected 1.0, got %.2f", mult)
	}
}

func TestStateMachine_HappyPath(t *testing.T) {
	for i := 0; i < 100; i++ {
		a := newMonster(battle.WuxingMetal, 100)
		d := newMonster(battle.WuxingWood, 100)

		s, err := battle.NewSession(a, d)
		if err != nil {
			t.Fatal(err)
		}
		if s.State != battle.StateIdle {
			t.Fatal("expected idle")
		}
		if err := s.Summon(); err != nil {
			t.Fatal(err)
		}
		if err := s.OpenMirrorWindow(); err != nil {
			t.Fatal(err)
		}
		ok, err := s.TryImprint()
		if err != nil {
			t.Fatal(err)
		}
		if ok {
			if s.State != battle.StateCaptured {
				t.Fatalf("expected captured, got %s", s.State)
			}
			return
		}
	}
	t.Fatal("imprint should eventually succeed")
}

func TestReverseGambit(t *testing.T) {
	a := newMonster(battle.WuxingWater, 100)
	d := newMonster(battle.WuxingFire, 100)
	d.CurrentHP = 25 // below 30% of 100

	s, _ := battle.NewSession(a, d)
	_ = s.Summon()
	// Don't open window yet; reverse gambit should open it
	// Move to summoned, simulate HP drop, then check reverse
	s.State = battle.StateSummoned

	triggered := s.CheckReverseGambit()
	if !triggered {
		t.Fatal("reverse gambit should trigger at HP < 30%")
	}
	if s.State != battle.StateMirrorWindowOpen {
		t.Fatalf("expected mirror_window_open, got %s", s.State)
	}
	// Second call must not trigger again
	if s.CheckReverseGambit() {
		t.Fatal("reverse gambit must not trigger twice")
	}
}
