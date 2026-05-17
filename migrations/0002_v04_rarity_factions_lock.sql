-- migrations/0002_v04_rarity_factions_lock.sql
-- ADR-002 v0.4: rarity domain alignment + factions + forge recipes + lock_state
-- Derived verbatim from docs/adr/ADR-002-v04-rarity-domain.md §3
-- Authors: Gemini 3.1 Pro (design) + Codex 5.5 Pro (review, 7 findings) + Cymon (integration)

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

-- Note: partial index WHERE expires_at > NOW() rejected by PostgreSQL
-- (NOW() is STABLE not IMMUTABLE). Use full index; filter expires_at in application.
CREATE INDEX idx_imprint_cooldowns_lookup
    ON imprint_cooldowns(victim_id, expires_at DESC);

COMMIT;
