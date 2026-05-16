# 應物 ECHO — 架構概覽

> ADR 詳見 docs/adr/。本文描述系統整體分層與資料流。

## 系統分層

    ┌─────────────────────────────────────────────┐
    │  Flutter App (Client)                        │
    │  screens/ → services/ApiClient               │
    └──────────────────┬──────────────────────────┘
                       │ HTTPS / WebSocket
    ┌──────────────────▼──────────────────────────┐
    │  Go / Gin HTTP Server                        │
    │  api/ handlers → internal domain packages    │
    │  battle/  forge/  monster/  player/          │
    └──────────────────┬──────────────────────────┘
                       │ pgx/v5
    ┌──────────────────▼──────────────────────────┐
    │  PostgreSQL 16                               │
    │  migrations/0001_initial_schema.sql (seed)   │
    └─────────────────────────────────────────────┘

## 核心 Domain Packages

### battle/
State machine: IDLE → SUMMONED → MIRROR_WINDOW_OPEN → CAPTURED | RETURNED_TO_OWNER
- 五行剋制矩陣（WuxingMatrix）：x1.35 攻 / x0.85 受剋
- 永久映刻（Imprint）：不歸還，寫入 player_monsters
- 落後反轉（ReverseGambit）：HP < 30% 觸發第二次映刻視窗

### forge/
三層機率煉化系統：
- L1 普通：書寫長度閘（>=50 字），100% 抽出
- L2 精怪：3 同 species + 200 字 + 3 心情貼，rand < 0.30
- L3 神獸：3 同 species 精怪 + 500 字 + 5 天活躍，rand < 0.10

### monster/
- MonsterSpecies（25 物種）x MonsterVariant（4 五行 × 25 = 100）
- 詞條池（ci_tiao_pool）：CHECK 長度 <=20 字，ability_verb <=15 字

### player/
- 5 派 enum：解構者 / 引流人 / 觀測使 / 調律師 / 築夢匠
- 每派 3 技能，seed 在 data/seed/factions.json

## 資料庫設計原則

- snake_case 命名
- 所有 enum 集中於 migration 頂部（wuxing / three_phase / rarity_tier / triangle_pos）
- CHECK constraints 在 schema 層強制業務規則（詞條長度、power_base 範圍）
- migrations/ 目錄按序累加，不回溯修改已上線版本

## 待決定（TODO / ADR 候選）

- [ ] ADR-001：WebSocket vs. HTTP Long-Poll for battle real-time sync
- [ ] ADR-002：JWT vs. Session cookie for auth
- [ ] ADR-003：Flutter state management（Riverpod vs. Bloc）
- [ ] ADR-004：AI 書寫分析 endpoint（本地模型 vs. 外部 API）
