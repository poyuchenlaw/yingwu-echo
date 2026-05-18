-- 0009_v06_journal_player_id.sql
-- v0.6.1: add location_alias column (separate from gemini-detected scene_tag),
-- add index on (player_id, written_at) for fast journal queries.

ALTER TABLE player_writings
  ADD COLUMN IF NOT EXISTS location_alias VARCHAR(80) DEFAULT '';

-- Index for journal listing: per-player, newest first
CREATE INDEX IF NOT EXISTS idx_player_writings_player_time
  ON player_writings(player_id, written_at DESC);
