# ⚔️ 六角格戰棋遊戲引擎 (Hex Grid Tactical RPG Engine) - 開發手冊

本文件記錄專案的核心架構、模組職責、目前已完成之功能與未來開發規劃。

---

## 📁 專案架構與模組分工 (Project Architecture)

專案嚴格採用**模組化設計**，將「空間幾何」、「渲染呈現」、「資料實體」與「核心流程」解耦（Decoupling）：

```text
src/
├── map/                  # 【地圖與幾何系統】(幾何數學、地圖生成、A* 尋路)
│   ├── HexNode.ts        # 立方體座標點 (Cube Coordinates) 與狀態
│   ├── HexGrid.ts        # 六角格地圖資料結構與鄰居/距離計算
│   └── Pathfinder.ts     # A* 尋路與廣度優先 (BFS) 移動範圍計算
├── render/               # 【渲染系統】(Canvas 繪圖)
│   └── HexRenderer.ts    # 負責地圖、範圍底色、單位棋子與 HP 的繪製[cite: 1]
├── entities/             # 【實體與數據】(單位與數值定義)
│   ├── Job.ts            # 職業數值配置 (移動力、攻擊射程 min/max)
│   └── Unit.ts           # 場上單位物件 (HP、座標、陣營、行動狀態)
├── core/                 # 【遊戲核心與狀態機】(遊戲大腦)
│   ├── GameState.ts      # 遊戲狀態機列舉 (GameState Enum)
│   └── GameManager.ts    # 總管回合切換、單位生命週期與全員結算
└── main.ts               # 【前端入口】(事件監聽、畫面渲染協調)

```

---

## ⚙️ 核心機制與狀態機 (State Machine)

遊戲運作由 `GameManager` 中的 `GameState` 嚴格控制，避免非當前階段的玩家操作輸入：

```
[INIT] ──> [TURN_START] ──> [PLAYER_PHASE] ──> [UNIT_SELECTED]
                                ↑                      │
                                │                      ▼
                           [TURN_END]  <─── [ENEMY_PHASE] (AI 計算)

```

1. **`TURN_START`**：重置場上所有我方/敵方單位的 `hasActed` 狀態為 `false`。
2. **`PLAYER_PHASE`**：等待玩家點擊選取單位。
3. **`UNIT_SELECTED`**：顯示該單位之移動範圍 (綠色)，移動後顯示攻擊範圍 (紅色)。
4. **`ENEMY_PHASE`**：我方全員行動完畢時自動觸發，鎖定玩家輸入，由敵方 AI 執行行動。
5. **`TURN_END`**：回合數 `turnCount` 遞增，並回到 `TURN_START` 啟動新回合。

---

## 📝 變更歷史 (Changelog)

### v1.0 - 核心幾何與繪圖

* 完成尖頂朝上六角格（Flat-topped / Pointy-topped）之立方体座標系 ($x, y, z$)。
* 實作 Canvas 雙向反向矩陣轉換 (`pixelToHex` / `getPixelCoords`)。



### v1.1 - 尋路與規則機制

* 整合 A* 尋路演算法與 BFS 範圍搜尋。


* 新增移動力上限限制與障礙物（牆壁）即時動態避障。



### v1.2 - 模組化與多單位戰鬥邏輯

* 專案結構模組化拆分（`map`, `render`, `entities`, `core`）。
* 引入 `GameManager` 狀態機，防止回合交接期間的輸入衝突。
* 支援同回合內我方多單位（P1 劍士、P2 弓箭手）無縫選擇與切換。


* 實作攻擊判定、血量 (HP) 扣減與單位死亡消滅機制。



---

## 📌 未來開發規劃 (TODO List)

* [ ] **敵方 AI 系統 (Enemy Phase AI)**：實作簡單 AI，會自動尋找最近目標靠近並攻擊。
* [ ] **勝負判定 (Win / Loss Condition)**：敵方全滅跳出 Victory，我方全滅跳出 Game Over。
* [ ] **地形與移動消耗 (Terrain Cost)**：不同地形（如森林、水域）消耗不同的移動力。
* [ ] **技能/魔法攻擊 (Skills & Magic)**：新增耗魔（MP）與範圍傷害 (AoE) 的職業技能。

---
