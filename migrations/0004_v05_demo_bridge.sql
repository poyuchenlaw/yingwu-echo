-- 0004_v05_demo_bridge.sql — v0.5 demo path 過渡欄位
-- Why: handler API 接 emotion_tag (string)、需存 content (TEXT) 才能 worker 讀回去丟給 Gemini
-- 這層橋接是 v0.5 demo 必要，未來改 content-addressed 儲存時 deprecate

BEGIN;

ALTER TABLE player_writings
  ADD COLUMN IF NOT EXISTS content TEXT,
  ADD COLUMN IF NOT EXISTS emotion_tag VARCHAR(20),
  ADD COLUMN IF NOT EXISTS scene_tag VARCHAR(20);

-- Gemini 心語有時 >40 字，擴到 120
ALTER TABLE player_writings
  ALTER COLUMN card_quote TYPE VARCHAR(120);

-- monster_name 多 byte CJK 30 字 = ~90 byte，擴到 80 字
ALTER TABLE player_writings
  ALTER COLUMN monster_name TYPE VARCHAR(80);

-- celestial_detected 既有 varchar(20)，海王星 3 字 OK，no change
-- wuxing_detected 是 enum (metal/wood/water/fire/earth)，handler 需做 CN→EN map

COMMENT ON COLUMN player_writings.content IS 'v0.5 demo: full content. v0.6+ migrate to content-addressed blob store via content_hash.';
COMMENT ON COLUMN player_writings.emotion_tag IS 'v0.5 demo: zh emotion string. v0.6+ resolve to emotions.id FK.';
COMMENT ON COLUMN player_writings.scene_tag IS 'v0.5 demo: zh scene string. v0.6+ resolve to scenes.id FK.';

COMMIT;
