# 應物 ECHO

> 以言應物，以物塑我。

《應物 ECHO》是一款以「書寫養成」為核心的靈魂怪獸收集遊戲。玩家透過每日書寫
產生靈魂墨水，煉化並培育共鳴體（怪獸），在鏡境中對決映刻。

**PROPRIETARY — 未經授權，禁止複製、散佈或傳送本程式碼的任何部分。**

---

## 快速啟動（開發環境）

### 前置需求

| 工具 | 版本 |
|------|------|
| Go | 1.22+ |
| PostgreSQL | 16 |
| Flutter | 3.x |
| Docker（選用） | 24+ |

### 1. 資料庫初始化

    createdb yingwu_echo_dev
    psql yingwu_echo_dev < migrations/0001_initial_schema.sql

### 2. 後端啟動

    cd backend
    cp config/config.example.yaml config/config.yaml
    go run ./cmd/server

預設監聽 :8080。

### 3. Seed 資料

    bash scripts/seed.sh

將 data/monsters/ 下的 JSON 批次寫入 monster_species / monster_variants。

### 4. Flutter 前端

    cd frontend
    flutter pub get
    flutter run

---

## 目錄結構

    yingwu-echo/
    ├── backend/
    │   ├── cmd/server/         # 程式進入點
    │   ├── internal/
    │   │   ├── battle/         # 戰鬥 state machine（五行剋制、映刻）
    │   │   ├── forge/          # 煉化引擎（三層機率系統）
    │   │   ├── monster/        # 怪獸 CRUD + variant 管理
    │   │   ├── player/         # 玩家、5 派技能
    │   │   ├── api/            # HTTP handlers（Gin）
    │   │   └── db/             # 資料庫 connection pool
    │   └── pkg/                # 共用工具（wuxing 計算、亂數種子）
    ├── frontend/
    │   └── lib/
    │       ├── screens/        # 主畫面
    │       ├── widgets/        # 共用元件
    │       ├── models/         # Dart 資料模型
    │       └── services/       # API client
    ├── data/
    │   ├── monsters/           # 100 variants seed JSON
    │   └── seed/               # 詞條池、派別技能 seed
    ├── migrations/             # PostgreSQL DDL
    ├── assets/                 # 青銅紋飾美術佔位
    ├── docs/
    │   ├── specs/              # v0.3 規格書
    │   └── adr/                # 架構決策紀錄
    ├── scripts/
    │   ├── seed.sh
    │   └── ops/
    └── tests/

---

## 核心概念

### 五行屬性

| 五行 | 寫作功能 | 剋制對象 |
|------|---------|---------|
| 金 | 批判 | 木 |
| 木 | 創造 | 土 |
| 水 | 情感 | 火 |
| 火 | 激情 | 金 |
| 土 | 紀實 | 水 |

剋制倍率：x1.35（攻方）/ x0.85（受剋方）。

### 怪獸稀有度

| 稀有度 | 煉化條件 | 觸發機率 |
|--------|---------|---------|
| 普通 | 書寫 >=50 字 | 100% |
| 精怪 | 3 同 species 普通 + >=200 字 + 3 心情貼 | 30% |
| 神獸 | 3 同 species 精怪 + >=500 字 + 5 天活躍 | 10% |

### 玩家 5 派

解構者 / 引流人 / 觀測使 / 調律師 / 築夢匠。每派 3 項技能。

---

## 貢獻指南

1. 本 repository 為 private，僅授權開發成員存取。
2. 每個功能開一個 feature branch：feature/<簡述>。
3. PR 須附對應 migration（若有 schema 變更）。
4. Go 程式碼遵循 gofmt；Dart 遵循 dart format。
5. 新增怪獸 variant 須同步更新 data/monsters/ seed JSON。
6. 詳細規格見 docs/specs/。

---

**PROPRIETARY SOFTWARE — Copyright © 2026 Simon Chen. All rights reserved.**
