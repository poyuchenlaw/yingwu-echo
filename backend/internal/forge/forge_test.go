package forge_test

import (
	"testing"

	"github.com/simonchen/yingwu-echo/backend/internal/forge"
)

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
