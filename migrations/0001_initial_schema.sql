-- migrations/0001_initial_schema.sql
-- 應物 ECHO — 初始 Schema (v0.3)
-- PostgreSQL 16
-- 執行: psql yingwu_echo_dev < migrations/0001_initial_schema.sql

BEGIN;

-- ============================================================
-- SECTION 0: ENUMs
-- ============================================================

CREATE TYPE wuxing AS ENUM (
    'metal',   -- 金：批判
    'wood',    -- 木：創造
    'water',   -- 水：情感
    'fire',    -- 火：激情
    'earth'    -- 土：紀實
);

CREATE TYPE three_phase AS ENUM (
    'biomorphic',   -- 生機體：有機動植物形態
    'tectonic',     -- 構造體：礦石機械幾何形態
    'phantasmal'    -- 靈質體：能量光影流動形態
);

CREATE TYPE rarity_tier AS ENUM (
    'common',    -- 普通
    'rare',      -- 精怪
    'legendary'  -- 神獸
);

CREATE TYPE triangle_pos AS ENUM (
    'attacker',   -- 攻擊位
    'defender',   -- 防禦位
    'support'     -- 輔助位
);

-- ============================================================
-- SECTION 1: MONSTER SPECIES (25 物種)
-- ============================================================

CREATE TABLE monster_species (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name_zh       VARCHAR(20) NOT NULL UNIQUE,
    name_en       VARCHAR(60) NOT NULL,
    base_phase    three_phase NOT NULL,
    -- 5x5x4 矩陣的情緒維度（5 情緒 x 5 場景 = 25 物種）
    emotion_tag   VARCHAR(20) NOT NULL,
    scene_tag     VARCHAR(20) NOT NULL,
    lore_excerpt  TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SECTION 2: MONSTER VARIANTS (100 variants = 25 species x 4 wuxing)
-- ============================================================

CREATE TABLE monster_variants (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    species_id      UUID        NOT NULL REFERENCES monster_species(id) ON DELETE CASCADE,
    wuxing_attr     wuxing      NOT NULL,
    rarity          rarity_tier NOT NULL DEFAULT 'common',
    power_base      SMALLINT    NOT NULL CHECK (power_base BETWEEN 1 AND 10),
    hp_base         INT         NOT NULL DEFAULT 100,
    position        triangle_pos NOT NULL DEFAULT 'attacker',
    -- 美術佔位：實際圖片 hash 由 assets pipeline 填入
    art_placeholder VARCHAR(200),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (species_id, wuxing_attr)
);

-- ============================================================
-- SECTION 3: CI_TIAO POOL (詞條池)
-- ============================================================

CREATE TABLE ci_tiao_pool (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_id      UUID        NOT NULL REFERENCES monster_variants(id) ON DELETE CASCADE,
    -- 詞條本文：<=20 字
    tiao_text       VARCHAR(20) NOT NULL
        CHECK (char_length(tiao_text) <= 20),
    -- 能力動詞：<=15 字
    ability_verb    VARCHAR(15) NOT NULL
        CHECK (char_length(ability_verb) <= 15),
    wuxing_resonance wuxing,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SECTION 4: PLAYER_MONSTERS (玩家持有的怪獸)
-- ============================================================

CREATE TABLE player_monsters (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id       UUID        NOT NULL,  -- FK to users table (future migration)
    variant_id      UUID        NOT NULL REFERENCES monster_variants(id),
    nickname        VARCHAR(30),
    -- 永久映刻：imprinted_from_player_id 非 NULL 表示映刻自他人
    imprinted_from_player_id UUID,
    acquired_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- 當前成長值（由書寫累積）
    growth_points   INT         NOT NULL DEFAULT 0 CHECK (growth_points >= 0),
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE
);

-- ============================================================
-- SECTION 5: FORGE_RECORDS (煉化記錄)
-- ============================================================

CREATE TABLE forge_records (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id       UUID        NOT NULL,
    -- 消耗的 3 隻普通/精怪怪獸 IDs（JSON array）
    consumed_ids    UUID[]      NOT NULL,
    target_rarity   rarity_tier NOT NULL,
    writing_chars   INT         NOT NULL CHECK (writing_chars >= 0),
    emotion_tags    TEXT[],
    active_days     INT         NOT NULL DEFAULT 0,
    -- 煉化結果
    succeeded       BOOLEAN     NOT NULL,
    result_monster_id UUID      REFERENCES player_monsters(id),
    forged_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SECTION 6: EMOTIONS (心情貼)
-- ============================================================

CREATE TABLE emotions (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id       UUID        NOT NULL,
    emotion_label   VARCHAR(20) NOT NULL,
    wuxing_hint     wuxing,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SECTION 7: SCENES (場景 / 記憶錨點)
-- ============================================================

CREATE TABLE scenes (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id       UUID        NOT NULL,
    scene_tag       VARCHAR(20) NOT NULL,
    location_hint   VARCHAR(100),
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SECTION 8: PLAYER_WRITINGS (書寫紀錄)
-- ============================================================

CREATE TABLE player_writings (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id       UUID        NOT NULL,
    content_hash    VARCHAR(64),                -- SHA-256 of content (stored client-side)
    char_count      INT         NOT NULL CHECK (char_count >= 0),
    wuxing_detected wuxing,                     -- AI 分析結果（可為 NULL 待補）
    emotion_id      UUID        REFERENCES emotions(id),
    scene_id        UUID        REFERENCES scenes(id),
    written_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SECTION 9: BATTLES (鏡境對決)
-- ============================================================

CREATE TYPE battle_state AS ENUM (
    'idle',
    'summoned',
    'mirror_window_open',
    'captured',
    'returned_to_owner'
);

CREATE TABLE battles (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    attacker_player_id  UUID        NOT NULL,
    defender_player_id  UUID        NOT NULL,
    attacker_monster_id UUID        NOT NULL REFERENCES player_monsters(id),
    defender_monster_id UUID        NOT NULL REFERENCES player_monsters(id),
    state               battle_state NOT NULL DEFAULT 'idle',
    -- 映刻結果：captured_monster_id 非 NULL 表示映刻成功
    captured_monster_id UUID        REFERENCES player_monsters(id),
    reverse_gambit_triggered BOOLEAN NOT NULL DEFAULT FALSE,
    started_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at            TIMESTAMPTZ
);

-- ============================================================
-- SECTION 10: PLAYER_RATINGS (五維評分)
-- ============================================================

CREATE TABLE player_ratings (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    rater_player_id UUID        NOT NULL,
    rated_player_id UUID        NOT NULL,
    writing_id      UUID        REFERENCES player_writings(id),
    score           SMALLINT    NOT NULL CHECK (score BETWEEN 1 AND 5),
    dimension       VARCHAR(20) NOT NULL,   -- TODO: 五維 enum（下一版 ADR）
    rated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (rater_player_id, writing_id, dimension)
);

-- ============================================================
-- SECTION 11: INDEXES
-- ============================================================

CREATE INDEX idx_player_monsters_player   ON player_monsters(player_id);
CREATE INDEX idx_player_monsters_variant  ON player_monsters(variant_id);
CREATE INDEX idx_player_writings_player   ON player_writings(player_id);
CREATE INDEX idx_player_writings_date     ON player_writings(written_at);
CREATE INDEX idx_battles_attacker         ON battles(attacker_player_id);
CREATE INDEX idx_battles_defender         ON battles(defender_player_id);
CREATE INDEX idx_forge_records_player     ON forge_records(player_id);
CREATE INDEX idx_emotions_player_date     ON emotions(player_id, recorded_at);

COMMIT;
-- END: 0001_initial_schema.sql
