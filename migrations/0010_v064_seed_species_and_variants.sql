-- migrations/0010_v064_seed_species_and_variants.sql
-- v0.6.4 data fix: seed 25 monster_species + 25 common variants (+ rare/legendary cascades)
-- Problem: monster_species was empty on fresh DBs, so AcquireMonsterForWriting returned 0 rows
-- and no player could ever obtain a monster.
-- Idempotent: all INSERTs use ON CONFLICT DO NOTHING. Safe to land twice.
--
-- REQUIRES: migrations 0001-0009 already applied. Specifically:
--   - 0001: monster_species, monster_variants, global_legendary_count tables
--   - 0005: replaces UNIQUE(species_id, wuxing_attr) with UNIQUE(species_id,
--           wuxing_attr, rarity). If 0005 is skipped, Step 2 below silently
--           collides on the old 2-key unique and seeds wrong rarities.
-- The rare/legendary cascades (Steps 3/4) SELECT all common variants by
-- design (mirrors 0005/0007); ON CONFLICT keeps them safe against pre-
-- existing rows. Blast radius is the whole common variants table — not
-- scoped to the new 25 species — but every conflict is a no-op insert.
--
-- ============================================================
-- 25 (emotion × scene) → wuxing_attr mapping
-- (extracted verbatim from WuxingHint in prompts/templates.go)
-- ============================================================
--
--  emotion     scene     wuxing_hint  wuxing_attr (EN)   name_zh         name_en               base_phase
--  ─────────── ───────── ───────────  ──────────────────  ────────────    ───────────────────   ──────────────
--  累           通勤       土           earth               通勤累魂        WearyCommuteSoul      biomorphic
--  累           工作       土           earth               工作累魂        WearyWorkSoul         tectonic
--  累           睡前       水           water               睡前累魂        WearyBedtimeSoul      phantasmal
--  累           用餐       土           earth               用餐累魂        WearyMealSoul         biomorphic
--  累           獨處       水           water               獨處累魂        WearySolitudeSoul     tectonic
--  火大         通勤       火           fire                通勤火大魂      AngryCommuteSoul      phantasmal
--  火大         工作       火           fire                工作火大魂      AngryWorkSoul         biomorphic
--  火大         睡前       火           fire                睡前火大魂      AngryBedtimeSoul      tectonic
--  火大         用餐       火           fire                用餐火大魂      AngryMealSoul         phantasmal
--  火大         獨處       火           fire                獨處火大魂      AngrySolitudeSoul     biomorphic
--  想哭         通勤       水           water               通勤想哭魂      TearyCommuteSoul      tectonic
--  想哭         工作       水           water               工作想哭魂      TearyWorkSoul         phantasmal
--  想哭         睡前       水           water               睡前想哭魂      TearyBedtimeSoul      biomorphic
--  想哭         用餐       水           water               用餐想哭魂      TearyMealSoul         tectonic
--  想哭         獨處       水           water               獨處想哭魂      TearySolitudeSoul     phantasmal
--  好像懂了     通勤       金           metal               通勤好像懂了魂  DawnCommuteSoul       biomorphic
--  好像懂了     工作       金           metal               工作好像懂了魂  DawnWorkSoul          tectonic
--  好像懂了     睡前       木           wood                睡前好像懂了魂  DawnBedtimeSoul       phantasmal
--  好像懂了     用餐       木           wood                用餐好像懂了魂  DawnMealSoul          biomorphic
--  好像懂了     獨處       金           metal               獨處好像懂了魂  DawnSolitudeSoul      tectonic
--  平           通勤       土           earth               通勤平魂        StillCommuteSoul      phantasmal
--  平           工作       土           earth               工作平魂        StillWorkSoul         biomorphic
--  平           睡前       水           water               睡前平魂        StillBedtimeSoul      tectonic
--  平           用餐       土           earth               用餐平魂        StillMealSoul         phantasmal
--  平           獨處       水           water               獨處平魂        StillSolitudeSoul     biomorphic
--
-- base_phase assignment: cycling biomorphic/tectonic/phantasmal across the 25-cell grid
-- (9 biomorphic / 8 tectonic / 8 phantasmal). No gameplay significance — artist
-- uses this as visual-style hint; distribution kept even to avoid palette clustering.
-- ============================================================

BEGIN;

-- ────────────────────────────────────────────────────────────
-- Step 1: land 25 monster_species (idempotent on name_zh)
-- ────────────────────────────────────────────────────────────

INSERT INTO monster_species (name_zh, name_en, base_phase, emotion_tag, scene_tag, lore_excerpt)
VALUES
  -- ── 累 (Exhaustion) ──────────────────────────────────────
  ('通勤累魂', 'WearyCommuteSoul',     'biomorphic',  '累',       '通勤', NULL),
  ('工作累魂', 'WearyWorkSoul',        'tectonic',    '累',       '工作', NULL),
  ('睡前累魂', 'WearyBedtimeSoul',     'phantasmal',  '累',       '睡前', NULL),
  ('用餐累魂', 'WearyMealSoul',        'biomorphic',  '累',       '用餐', NULL),
  ('獨處累魂', 'WearySolitudeSoul',    'tectonic',    '累',       '獨處', NULL),
  -- ── 火大 (Anger) ─────────────────────────────────────────
  ('通勤火大魂', 'AngryCommuteSoul',   'phantasmal',  '火大',     '通勤', NULL),
  ('工作火大魂', 'AngryWorkSoul',      'biomorphic',  '火大',     '工作', NULL),
  ('睡前火大魂', 'AngryBedtimeSoul',   'tectonic',    '火大',     '睡前', NULL),
  ('用餐火大魂', 'AngryMealSoul',      'phantasmal',  '火大',     '用餐', NULL),
  ('獨處火大魂', 'AngrySolitudeSoul',  'biomorphic',  '火大',     '獨處', NULL),
  -- ── 想哭 (Near Tears) ────────────────────────────────────
  ('通勤想哭魂', 'TearyCommuteSoul',   'tectonic',    '想哭',     '通勤', NULL),
  ('工作想哭魂', 'TearyWorkSoul',      'phantasmal',  '想哭',     '工作', NULL),
  ('睡前想哭魂', 'TearyBedtimeSoul',   'biomorphic',  '想哭',     '睡前', NULL),
  ('用餐想哭魂', 'TearyMealSoul',      'tectonic',    '想哭',     '用餐', NULL),
  ('獨處想哭魂', 'TearySolitudeSoul',  'phantasmal',  '想哭',     '獨處', NULL),
  -- ── 好像懂了 (Dawning Clarity) ───────────────────────────
  ('通勤好像懂了魂', 'DawnCommuteSoul',   'biomorphic', '好像懂了', '通勤', NULL),
  ('工作好像懂了魂', 'DawnWorkSoul',      'tectonic',   '好像懂了', '工作', NULL),
  ('睡前好像懂了魂', 'DawnBedtimeSoul',   'phantasmal', '好像懂了', '睡前', NULL),
  ('用餐好像懂了魂', 'DawnMealSoul',      'biomorphic', '好像懂了', '用餐', NULL),
  ('獨處好像懂了魂', 'DawnSolitudeSoul',  'tectonic',   '好像懂了', '獨處', NULL),
  -- ── 平 (Neutral/Still) ───────────────────────────────────
  ('通勤平魂', 'StillCommuteSoul',    'phantasmal',  '平',       '通勤', NULL),
  ('工作平魂', 'StillWorkSoul',       'biomorphic',  '平',       '工作', NULL),
  ('睡前平魂', 'StillBedtimeSoul',    'tectonic',    '平',       '睡前', NULL),
  ('用餐平魂', 'StillMealSoul',       'phantasmal',  '平',       '用餐', NULL),
  ('獨處平魂', 'StillSolitudeSoul',   'biomorphic',  '平',       '獨處', NULL)
ON CONFLICT (name_zh) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- Step 2: land 25 common monster_variants, one per species.
-- wuxing_attr from templates.go WuxingHint (CN→EN enum map below).
-- power_base=5, hp_base=100, position='attacker'.
-- Conflict key: (species_id, wuxing_attr, rarity) — after 0005 migration.
-- ────────────────────────────────────────────────────────────

INSERT INTO monster_variants (species_id, wuxing_attr, rarity, power_base, hp_base, position, art_placeholder)
SELECT
  s.id,
  v.wuxing_attr::wuxing,
  'common'::rarity_tier,
  5,
  100,
  'attacker'::triangle_pos,
  'placeholder://' || s.name_en
FROM (VALUES
  -- (name_zh,            wuxing_attr)
  ('通勤累魂',            'earth'),
  ('工作累魂',            'earth'),
  ('睡前累魂',            'water'),
  ('用餐累魂',            'earth'),
  ('獨處累魂',            'water'),
  ('通勤火大魂',          'fire'),
  ('工作火大魂',          'fire'),
  ('睡前火大魂',          'fire'),
  ('用餐火大魂',          'fire'),
  ('獨處火大魂',          'fire'),
  ('通勤想哭魂',          'water'),
  ('工作想哭魂',          'water'),
  ('睡前想哭魂',          'water'),
  ('用餐想哭魂',          'water'),
  ('獨處想哭魂',          'water'),
  ('通勤好像懂了魂',      'metal'),
  ('工作好像懂了魂',      'metal'),
  ('睡前好像懂了魂',      'wood'),
  ('用餐好像懂了魂',      'wood'),
  ('獨處好像懂了魂',      'metal'),
  ('通勤平魂',            'earth'),
  ('工作平魂',            'earth'),
  ('睡前平魂',            'water'),
  ('用餐平魂',            'earth'),
  ('獨處平魂',            'water')
) AS v(name_zh, wuxing_attr)
JOIN monster_species s ON s.name_zh = v.name_zh
ON CONFLICT (species_id, wuxing_attr, rarity) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- Step 3: re-trigger rare cascade (mirrors 0005, now idempotent)
-- Picks up any common variant that lacks a matching rare sibling.
-- ────────────────────────────────────────────────────────────

INSERT INTO monster_variants (species_id, wuxing_attr, rarity, power_base, hp_base, position, art_placeholder)
SELECT
  species_id,
  wuxing_attr,
  'rare'::rarity_tier,
  LEAST(power_base + 3, 10),
  hp_base + 50,
  position,
  REPLACE(art_placeholder, '://', '://rare_')
FROM monster_variants
WHERE rarity = 'common'
ON CONFLICT (species_id, wuxing_attr, rarity) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- Step 4: re-trigger legendary cascade (mirrors 0007, now idempotent)
-- Picks up any common variant that lacks a matching legendary sibling.
-- ────────────────────────────────────────────────────────────

INSERT INTO monster_variants (species_id, wuxing_attr, rarity, power_base, hp_base, position, art_placeholder)
SELECT
  species_id, wuxing_attr, 'legendary'::rarity_tier,
  LEAST(power_base + 5, 10),
  hp_base + 150,
  position,
  REPLACE(art_placeholder, '://', '://legendary_')
FROM monster_variants
WHERE rarity = 'common'
ON CONFLICT (species_id, wuxing_attr, rarity) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- Step 5: land global_legendary_count rows (one per species, active_count=0)
-- 0007 did this too but monster_species was empty then → 0 rows.
-- ────────────────────────────────────────────────────────────

INSERT INTO global_legendary_count (species_id, active_count)
SELECT id, 0 FROM monster_species
ON CONFLICT (species_id) DO NOTHING;

COMMIT;
-- END: 0010_v064_seed_species_and_variants.sql
