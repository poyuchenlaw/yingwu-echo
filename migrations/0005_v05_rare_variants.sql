-- 0005_v05_rare_variants.sql — Forge 需要 rare variants 存在才能 resolveNewVariant
-- Why: monster_variants UNIQUE(species_id, wuxing_attr) 阻擋同 species 多 rarity
-- Fix: 改為 UNIQUE(species_id, wuxing_attr, rarity) 三鍵 + 種 rare variants

BEGIN;

ALTER TABLE monster_variants
  DROP CONSTRAINT monster_variants_species_id_wuxing_attr_key;

ALTER TABLE monster_variants
  ADD CONSTRAINT monster_variants_species_wuxing_rarity_key
  UNIQUE (species_id, wuxing_attr, rarity);

-- Seed rare variant for each (species, wuxing) — power +3, hp +50 vs common
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
WHERE rarity = 'common';

COMMIT;
