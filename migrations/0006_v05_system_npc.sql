-- 0006_v05_system_npc.sql — battle endpoint needs persistent NPC opponents
-- Why: battles table FK requires player_monsters row; seed 100 rare NPC monsters
-- for system_player_id so /api/v1/battle can pick adversaries.

BEGIN;

-- Seed system player monsters: 1 of each rare variant under fixed system player UUID
-- system_player_id = '00000000-0000-0000-0000-FFFFFFFFFFFF'
INSERT INTO player_monsters (id, player_id, variant_id, nickname, lock_state)
SELECT
  gen_random_uuid(),
  '00000000-0000-0000-0000-FFFFFFFFFFFF'::uuid,
  id,
  '山海者·' || (
    SELECT name_zh FROM monster_species WHERE id = monster_variants.species_id
  ),
  'free'
FROM monster_variants
WHERE rarity = 'rare';

COMMIT;
