-- 0007_v05_legendary_dedup.sql — legendary variants + writing dedup

BEGIN;

-- Seed legendary variant for each (species, wuxing) — power+5 vs common, hp+150
INSERT INTO monster_variants (species_id, wuxing_attr, rarity, power_base, hp_base, position, art_placeholder)
SELECT
  species_id, wuxing_attr, 'legendary'::rarity_tier,
  LEAST(power_base + 5, 10),
  hp_base + 150,
  position,
  REPLACE(art_placeholder, '://', '://legendary_')
FROM monster_variants
WHERE rarity = 'common';

-- Initialise global_legendary_count rows for all species
INSERT INTO global_legendary_count (species_id, active_count)
SELECT id, 0 FROM monster_species
ON CONFLICT (species_id) DO NOTHING;

-- Writing dedup: same player, same content_hash → reject duplicate
CREATE UNIQUE INDEX IF NOT EXISTS uniq_player_writings_content_hash
  ON player_writings (player_id, content_hash)
  WHERE content_hash IS NOT NULL;

COMMIT;
