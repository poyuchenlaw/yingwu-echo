# docs/specs/ — v0.3 規格書索引

| 檔案 | 內容 |
|------|------|
| v0.3_source03_termsworld.txt | Source 03 世界術語表 + 玩家 5 派 + 5x5x4 矩陣 |
| v0.3_source04_schema.md | Source 04 DB Schema + 戰鬥 state machine + 煉化機制（見 migration 0001） |
| v0.3_source05_naming.txt | Source 05 命名規則 + 品牌定位 |

## v0.3 核心規格摘要

### Source 04 已落地於
- migrations/0001_initial_schema.sql （完整 DDL）
- backend/internal/battle/engine.go （戰鬥 state machine）
- backend/internal/forge/forge.go （三層煉化機率）

### 待補規格（v0.4 優先項）
- Source 04 §五：玩家技能不直接傷害怪獸的具體技能表（現只有 faction seed）
- Source 04 §六：書寫 AI 分析端點規格（五行偵測模型）
- Source 03 §三：社交「贈送話語 / 共鳴流轉」詳細 schema
