-- Seed: 0002_factions.sql
-- 5 player_factions × 3 faction_skills = 15 skills + 3 forge_recipes
-- UUID strategy: uuid5(NAMESPACE_DNS, "yingwu.<entity>.<code>")
-- Generated: 2026-05-17

BEGIN;

-- ============================================================
-- player_factions (5 rows)
-- ============================================================
INSERT INTO player_factions (id, faction_code, name_zh, philosophy) VALUES
  ('54d01659-1d43-51f6-8654-243ed1e1864c', 'deconstructor', '解構者', '拆解情緒成最小單元，在碎片中看穿表面敘事，以理性切割抵達本質'),
  ('4676ec33-fee6-5892-a97b-38db29896e06', 'channeler',     '引流人', '把情緒導入他人共鳴，讓感知在橋樑間流動，形成跨越個體的回響'),
  ('a792f089-5a25-57be-9f7a-f984992ea89c', 'observer',      '觀測使', '在距離中標記能量座標，以冷靜目光丈量世界，座標即記憶即力量'),
  ('f8416d1c-972c-59c5-afcf-adea20be361e', 'tuner',         '調律師', '不取不奪，只讓萬物自鳴對位，在靜默中還原宇宙的本來頻率'),
  ('7313d8a0-ad8e-5901-8430-6ae6c08bf208', 'dreamer',       '築夢匠', '在夢境邊界把實體溶為念想，以想像力重塑存在，念想即現實');

-- ============================================================
-- faction_skills (15 rows = 5 factions × 3 skills each)
-- ============================================================
INSERT INTO faction_skills (id, faction_id, skill_code, name_zh, imprint_delta, trigger_phase, description) VALUES

  -- deconstructor ──────────────────────────────────────────
  -- skill 1 (aligned with imprint.go ModDeconstructorTrace Delta=0.05)
  ('4a913363-cc6e-5859-bec9-d599905ea17e',
   '54d01659-1d43-51f6-8654-243ed1e1864c',
   'deconstructor_trace', '痕跡解析', 0.05, 'mirror_window_open',
   '映刻窗口開啟時，解構者在目標情緒殘跡中留下細微刻痕，令映刻機率微幅上升。'),

  -- skill 2 (imprint_delta=0.07, trigger=imprint_attempt)
  ('30b353ae-d142-5ab5-85cf-3b9958ed4bc0',
   '54d01659-1d43-51f6-8654-243ed1e1864c',
   'deconstructor_split', '語義切分', 0.07, 'imprint_attempt',
   '映刻嘗試時，解構者把對方情緒切分為子單元，暴露結構空隙，提升映刻滲透率。'),

  -- skill 3 (imprint_delta=0.03, trigger=damage_resolve)
  ('34db628d-0a93-560a-988c-fad4181c6eb4',
   '54d01659-1d43-51f6-8654-243ed1e1864c',
   'deconstructor_anatomize', '深層解剖', 0.03, 'damage_resolve',
   '傷害結算後，解構者對殘餘情緒進行解剖分析，積累下次映刻的精準度小幅加成。'),

  -- channeler ──────────────────────────────────────────────
  -- skill 1 (aligned with imprint.go ModChannelerTearImprint Delta=0.10)
  ('3d85b971-98c4-57f4-a039-49e3c9566e02',
   '4676ec33-fee6-5892-a97b-38db29896e06',
   'channeler_tear_imprint', '淚痕映刻', 0.10, 'imprint_attempt',
   '映刻嘗試時，引流人以淚痕為媒介，引導情感共鳴穿越防線，顯著提升映刻成功率。'),

  -- skill 2 (imprint_delta=0.08, trigger=summoned)
  ('e0c30d94-5fe3-5735-a1c2-d03155673ec6',
   '4676ec33-fee6-5892-a97b-38db29896e06',
   'channeler_resonate', '共鳴引導', 0.08, 'summoned',
   '召喚時，引流人即在場域中架設情感橋樑，令後續所有映刻行動共享初始共鳴加成。'),

  -- skill 3 (imprint_delta=0.05, trigger=damage_resolve)
  ('424ecaaa-e283-5221-ad1d-a0f7c8db6c04',
   '4676ec33-fee6-5892-a97b-38db29896e06',
   'channeler_overflow', '情感溢流', 0.05, 'damage_resolve',
   '傷害結算後，積壓情感溢出為映刻動能，轉化部分傷害成下次映刻的機率加成。'),

  -- observer ───────────────────────────────────────────────
  -- skill 1 (aligned with imprint.go ModObserverMark Delta=0.15)
  ('00e0dce8-8596-5057-a1b0-728e5fa1c033',
   'a792f089-5a25-57be-9f7a-f984992ea89c',
   'observer_mark', '座標標記', 0.15, 'summoned',
   '召喚時即在目標能量場標記座標，距離越遠觀測越清晰，大幅提升映刻命中基準。'),

  -- skill 2 (imprint_delta=0.10, trigger=imprint_attempt)
  ('8a2d91f8-68c3-56d0-99f3-7cda87ea0f35',
   'a792f089-5a25-57be-9f7a-f984992ea89c',
   'observer_survey', '全域掃描', 0.10, 'imprint_attempt',
   '映刻嘗試時，觀測使以全景視野掃描目標情緒盲區，消除不確定性，提升映刻精度。'),

  -- skill 3 (imprint_delta=0.08, trigger=damage_resolve)
  ('5301bde2-8c3b-587e-a486-3757915c9203',
   'a792f089-5a25-57be-9f7a-f984992ea89c',
   'observer_triangulate', '三角定位', 0.08, 'damage_resolve',
   '傷害結算後，觀測使以三點定位法鎖定目標殘餘情緒座標，為下次映刻積累定位加成。'),

  -- tuner ──────────────────────────────────────────────────
  -- skill 1 (aligned with imprint.go ModTunerChord Delta=0.00)
  ('746b0809-7c72-50ed-9b52-2b7d9ef7aacf',
   'f8416d1c-972c-59c5-afcf-adea20be361e',
   'tuner_chord', '對位和弦', 0.00, 'damage_resolve',
   '傷害結算時，調律師不增不減，令場域頻率自然對齊，維持映刻機率於基準穩態。'),

  -- skill 2 (imprint_delta=-0.03, trigger=summoned; 謙讓，讓出動能)
  ('2ff6ec97-c2da-5e0a-a26a-0fe86607f9bb',
   'f8416d1c-972c-59c5-afcf-adea20be361e',
   'tuner_yield', '謙讓頻率', -0.03, 'summoned',
   '召喚時主動讓出部分映刻動能，以自我克制換取場域共鳴穩定，為後手策略留餘地。'),

  -- skill 3 (imprint_delta=0.02, trigger=imprint_attempt)
  ('47e8cd68-5c2e-5cfc-a8dc-f2f7b1f2c2af',
   'f8416d1c-972c-59c5-afcf-adea20be361e',
   'tuner_align', '頻率校準', 0.02, 'imprint_attempt',
   '映刻嘗試時，調律師微調自身頻率與目標對齊，以最小干預換取細微但確實的映刻增益。'),

  -- dreamer ────────────────────────────────────────────────
  -- skill 1 (aligned with imprint.go ModDreamerDissolve Delta=0.20)
  ('e97e6511-3766-54a6-8b32-833b43bf541f',
   '7313d8a0-ad8e-5901-8430-6ae6c08bf208',
   'dreamer_dissolve', '實體消解', 0.20, 'mirror_window_open',
   '映刻窗口開啟時，築夢匠將目標存在感溶入念想之間，令防禦邊界模糊，獲得最高映刻加成。'),

  -- skill 2 (imprint_delta=0.10, trigger=imprint_attempt; sum cap: 0.20+0.10+0.10=0.40)
  ('7a9f3496-2b64-511f-a83f-b0fdbb9023eb',
   '7313d8a0-ad8e-5901-8430-6ae6c08bf208',
   'dreamer_drift', '夢境漂移', 0.10, 'imprint_attempt',
   '映刻嘗試時，築夢匠使目標意識漂入夢境邊緣，現實感鬆動令映刻穿透力大幅提升。'),

  -- skill 3 (imprint_delta=0.10, trigger=summoned)
  ('feb68184-eab3-5101-bdcc-076b54c7f278',
   '7313d8a0-ad8e-5901-8430-6ae6c08bf208',
   'dreamer_membrane', '夢膜展開', 0.10, 'summoned',
   '召喚時在場域外圍鋪展夢境薄膜，將整個戰場籠罩於半夢半醒之境，為後續映刻預熱加成。');

-- ============================================================
-- forge_recipes (2 rows per ADR-002 §2.3)
-- ============================================================
INSERT INTO forge_recipes (id, target_rarity, source_count, source_rarity, chars_required, extra_material) VALUES
  ('11934c20-8ccd-5727-b7a0-df31df3356a3',
   'rare', 3, 'common', 500, NULL),
  ('013392bf-7e81-55b9-847d-c306faf8c611',
   'legendary', 3, 'rare', 2000,
   '{"type":"shard","species_constraint":"any_legendary"}'::jsonb);

COMMIT;
