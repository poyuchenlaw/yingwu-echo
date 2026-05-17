# ADR-002: v0.4 Rarity 領域模型與煉化機制

**Status**: PROPOSED（待 Auditor 紅線審）
**Date**: 2026-05-17
**Authors**:
- Gemini 3.1 Pro — 主筆設計
- Codex 5.5 Pro — 架構審查（揭 7 findings，3 P0）
- Cymon (Claude Opus 4.7) — 整合 + 收斂
**Supersedes**: v0.3.6「強卡要弱卡堆疊煉化」口語規格

---

## 1. Context

v0.3.6 留 4 open 漏洞 + Gemini 揭 2 條 + Codex 揭 7 條 = 13 條一次收斂。

關鍵發現（Codex F1-F2 是 deal-breaker）：
- **三套 Rarity 命名互不相容**：DB enum 用 `rare`、imprint.go 用 `Refined/Divine`、ADR v1 用 `refined/legendary`。
- **25 species × (phase, emotion) 分桶只有 1 桶 ≥5 species**（靈質體×想哭=5），原 recipe「5 refined 同 phase+emotion」99% 玩家無法產第二條 legendary path。

---

## 2. Decisions

### 2.1 Rarity 命名 — 對齊 DB enum

以 `0001_initial_schema.sql:26-30` 的 `('common', 'rare', 'legendary')` 為唯一 truth。

- `imprint.go`：`RarityRefined` → `RarityRare`；`RarityDivine` → `RarityLegendary`
- `imprint_test.go`：兩 case 同步 rename
- `engine.go:143`：寫死 `RarityCommon` → `s.TargetRarity`

### 2.2 Rarity State Machine

```
common ──forge(3 cards + 500 effective chars)──► rare
rare   ──forge(3 cards + 殘卷 + 2000 effective chars)──► legendary
```

單向不可逆；不可降階；不可跳階。

### 2.3 Forge Recipe（Codex F2 改放寬）

| Target | 弱卡需求 | 累積字數 | 額外材料 |
|--------|---------|---------|---------|
| rare | 3 張 common，同 emotion_tag + 同 wuxing（不限同物種） | 500 有效字 | — |
| legendary | 3 張 rare，同 emotion_tag（不限 base_phase） | 2000 有效字 | 神獸殘卷 × 1 |

「有效字」= `char_count × validity_score`（rounded down）

SQL eligibility 範例（Codex F7 要求）：

```sql
SELECT pm.id, mv.wuxing_attr, ms.emotion_tag
FROM player_monsters pm
JOIN monster_variants mv ON pm.variant_id = mv.id
JOIN monster_species ms ON mv.species_id = ms.id
WHERE pm.player_id = $1
  AND mv.rarity = 'common'
  AND pm.lock_state = 'free'
GROUP BY mv.wuxing_attr, ms.emotion_tag
HAVING COUNT(*) >= 3;
```

### 2.4 Imprint Probability × Rarity

| Rarity | base_prob |
|--------|-----------|
| common | 0.80 |
| rare | 0.50 |
| legendary | 0.25 |

### 2.5 神獸稀缺保護

- 全服單物種上限 **99 隻**活躍 legendary
- 觸發上限 → REJECTED，退 **80% 弱卡** + **100% 字數累積保留**
- 釋放路徑（Codex F4）：玩家刪號 `-= owned_count`；神獸 mark_deleted `-= 1`；被搶（換手）不變
- 每玩家神獸持有上限 **5 隻**

### 2.6 Wuxing / Position 繼承

| 屬性 | rare | legendary |
|------|------|-----------|
| wuxing | 嚴格鎖 | 嚴格鎖（v0.5 五行石可洗一次） |
| triangle_pos | 取多數位，平局 attacker 優先 | 全鎖 |

### 2.7 Imprint 冷卻

| 條件 | 冷卻 |
|------|------|
| 被搶 legendary | 24h 全域冷卻 |
| 被搶 rare | 6h 對同一攻擊者冷卻 |
| 1h 內被搶 ≥3 次 | 自動 12h 全保護 |

`imprint_cooldowns` insert 必須在 battle UPDATE 同一 TX（Codex F4）。

### 2.8 Forge / Battle 併發鎖（Codex F5）

新增 `player_monsters.lock_state ENUM('free', 'in_forge', 'in_battle', 'imprint_cooldown')`。

- forge：`SELECT ... FOR UPDATE` 鎖 source cards → UPDATE `lock_state='in_forge'` → 銷毀 row
- battle：進 `mirror_window_open` 前 SELECT 目標 `lock_state='free'`（FOR SHARE）；若 `in_forge` → 拒絕
- imprint 成功：同 TX UPDATE 新 owner + `lock_state='imprint_cooldown'` + insert cooldown
- 背景 worker：到期 UPDATE `lock_state='free'`

---

## 3. Schema 變更（驅動 migration 0002）

```sql
BEGIN;

-- A1. player_writings: AI 分析結果 + validity_score
ALTER TABLE player_writings
    ADD COLUMN status              VARCHAR(32)    NOT NULL DEFAULT 'pending_analysis',
    ADD COLUMN celestial_detected  VARCHAR(20),
    ADD COLUMN monster_name        VARCHAR(60),
    ADD COLUMN card_quote          VARCHAR(40),
    ADD COLUMN validity_score      NUMERIC(3,2)   NOT NULL DEFAULT 0.50
        CHECK (validity_score BETWEEN 0.00 AND 1.00),
    ADD COLUMN analyzed_at         TIMESTAMPTZ;

-- A2. player_monsters: lock_state
ALTER TABLE player_monsters
    ADD COLUMN lock_state    VARCHAR(20) NOT NULL DEFAULT 'free'
        CHECK (lock_state IN ('free', 'in_forge', 'in_battle', 'imprint_cooldown')),
    ADD COLUMN wuxing_locked BOOLEAN     NOT NULL DEFAULT TRUE;

CREATE INDEX idx_player_monsters_lock_state ON player_monsters(lock_state)
    WHERE lock_state != 'free';

-- B1. player_factions
CREATE TABLE player_factions (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    faction_code  VARCHAR(32)  NOT NULL UNIQUE,
    name_zh       VARCHAR(20)  NOT NULL,
    philosophy    TEXT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- B2. faction_skills（5 × 3 = 15）
CREATE TABLE faction_skills (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    faction_id      UUID         NOT NULL REFERENCES player_factions(id) ON DELETE CASCADE,
    skill_code      VARCHAR(40)  NOT NULL UNIQUE,
    name_zh         VARCHAR(20)  NOT NULL,
    imprint_delta   NUMERIC(4,2) NOT NULL DEFAULT 0.00,
    trigger_phase   VARCHAR(20),
    description     VARCHAR(140)
);

-- B3. forge_recipes（靜態配方）
CREATE TABLE forge_recipes (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    target_rarity   rarity_tier  NOT NULL UNIQUE,
    source_count    SMALLINT     NOT NULL,
    source_rarity   rarity_tier  NOT NULL,
    chars_required  INT          NOT NULL,
    extra_material  JSONB,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- B4. global_legendary_count
CREATE TABLE global_legendary_count (
    species_id    UUID         PRIMARY KEY REFERENCES monster_species(id) ON DELETE CASCADE,
    active_count  INT          NOT NULL DEFAULT 0
        CHECK (active_count >= 0 AND active_count <= 99),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- B5. imprint_cooldowns
CREATE TABLE imprint_cooldowns (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    victim_id     UUID         NOT NULL,
    attacker_id   UUID,
    rarity_scope  rarity_tier,
    expires_at    TIMESTAMPTZ  NOT NULL,
    reason        VARCHAR(40)  NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Full index (partial WHERE NOW() rejected by PostgreSQL: NOW() is STABLE not IMMUTABLE)
-- Application filters expires_at > NOW() at query time
CREATE INDEX idx_imprint_cooldowns_lookup
    ON imprint_cooldowns(victim_id, expires_at DESC);

COMMIT;
```

注意：`forge_records.consumed_ids UUID[]` 既有設計問題留 v0.5 改 junction table（Codex F6 followup）。`emotion_tag` enum 化亦留 v0.5。

---

## 4. Consequences

### 對既有 test 衝擊（Codex F3 完整 checklist）
- `imprint.go` 三常數 rename：`RarityRefined→RarityRare`、`RarityDivine→RarityLegendary`、保留 `RarityCommon`
- `imprint_test.go:24,62` 兩 case 同步
- `engine.go:143` TryImprint 改吃 `s.TargetRarity` + accept modifiers param
- `engine_test.go` TryImprint_UsesRNG 改呼叫新簽名
- `forge_test.go` 留 P3 之後測 rare/legendary recipe case

### Trade-off
- 99 全服上限可能引發炒作 → v0.5 交易市場
- 24h 冷卻可能被利用刷保護期 → v0.5 abuse detection

---

## 5. Alternatives Considered

| Alt | 駁回理由 |
|-----|---------|
| 機率性煉化失敗 | 違反鼓勵書寫初衷（Gemini） |
| 取消 legendary 階級 | 失去 endgame（Gemini） |
| legendary 維持 5 cards 同 phase | 100 species 分佈不可達（Codex F2） |
| ADR 用 refined/divine 命名 | 已落地 DB 用 rare（Codex F1） |
| advisory lock 取代 lock_state | 跨 session 狀態不可見、debug 痛苦（Cymon） |

---

## 6. Followup（v0.5）

- 神獸殘卷 item system
- AI analyzer validity_score 演算法 spec
- 五行石洗鍊
- forge_records 改 junction table
- emotion_tag → ENUM
- 神獸交易市場
- imprint abuse detection

---

## 7. Multi-model 辯論軌跡

| 輪 | 模型 | 角色 | 主要貢獻 |
|----|------|------|---------|
| 1 | Gemini 3.1 Pro | 主筆 | state machine / forge formula / 稀缺保護 / 冷卻 |
| 2 | Codex 5.5 Pro | 架構審 | NO-GO + 7 findings：命名衝突、recipe 數學不可達、rename 衝擊面、race、schema 細節 |
| 3 | Cymon (Claude) | 整合 | 採 Codex F1 對齊 enum、F2 改 3 cards 移除 phase、F3 完整 rename checklist、F4 釋放路徑、F5 lock_state、F6 JSONB+index、F7 SQL 範例 |

Auditor (sonnet fresh window) 待 schema 落地後紅線審。
