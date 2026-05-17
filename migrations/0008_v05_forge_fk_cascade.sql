-- 0008 — forge_records.result_monster_id FK 改 ON DELETE SET NULL
-- Why: legendary forge consumes rares that may themselves be prior forge results;
-- without CASCADE/SET NULL the DELETE FROM player_monsters fails.

BEGIN;

ALTER TABLE forge_records
  DROP CONSTRAINT IF EXISTS forge_records_result_monster_id_fkey;

ALTER TABLE forge_records
  ADD CONSTRAINT forge_records_result_monster_id_fkey
  FOREIGN KEY (result_monster_id) REFERENCES player_monsters(id) ON DELETE SET NULL;

-- Reset bogus legendary count from prior partial-transaction failure
UPDATE global_legendary_count SET active_count = 0 WHERE active_count > 0;

COMMIT;
