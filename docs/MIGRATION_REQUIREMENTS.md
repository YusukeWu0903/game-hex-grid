# 六角格戰棋 Godot 移植需求

本次採使用者確認的基準版範圍：Godot 2D，保留棋盤風格與劍士、弓箭手；修正現有系統，提供明確指令，每場戰前全員恢復 HP／MP。詳細規則以 GAME_SPEC.md 為準。

## 需求與實作對照

| 編號 | 需求 | 實作位置 | 驗收依據 |
| --- | --- | --- | --- |
| R01 | 原版保留，獨立移植 | 原版 hex-grid-demo、新版 hex-grid-godot | 原版工作目錄仍乾淨，原 commit 未變 |
| R02 | Godot 4 與 GDScript | project.godot、scenes/main.tscn | Godot 4.6.3 匯入與啟動成功 |
| R03 | 六角座標、兩張原地圖 | core/hex_rules.gd、data/maps | 61 格、座標往返、原檔 SHA256 一致 |
| R04 | 共用地形與尋路規則 | core/hex_rules.gd | 平地、森林、山水、佔格與繞路測例 |
| R05 | 單一隊伍 ID 來源 | data/catalog.json、core/catalog.gd | 未選角色不可部署，選角保存重讀一致 |
| R06 | 安全部署 | core/battle_session.gd | 缺少角色、出生點不足、重疊皆拒絕 |
| R07 | 完整戰鬥循環 | core/battle_session.gd、ui/main.gd | 兩張地圖完整模擬、勝敗 UI、重試 |
| R08 | 角色旁五鍵環狀圖示指令 | ui/main.gd、ui/radial_actions.gd、ui/action_icon_button.gd | 方位、收合、取消兩層、停用狀態、邊界與縮放皆有測例 |
| R09 | MP 與射程雙重驗證 | core/battle_rules.gd | MP14／15、射程1／2／3／4、不得重複攻擊 |
| R10 | 動畫鎖定與舊流程隔離 | ui/main.gd | 連點鎖定、敵方回合退出再重開測例 |
| R11 | 合法 AI | core/battle_rules.gd | 森林移動成本、貼身弓手退到射程 |
| R12 | 地圖編輯 | ui/main.gd、core/data_store.gd | 筆刷、出生點、編輯隔離、JSON 往返 |
| R13 | 關卡編輯 | ui/main.gd、core/data_store.gd | 統一選角、敵軍配置、目標驗證 |
| R14 | 保存與無效資料保護 | core/data_store.gd | 保存重讀、拒絕無效資料、保留暫時不可玩關卡 |
| R15 | 戰鬥表現 | ui/hex_board.gd、ui/game_audio.gd | 移動、範圍、血魔條、傷害、回合與結果截圖 |
| R16 | 測試與視覺驗收 | tests/、docs/VALIDATION.md | 見 VALIDATION.md 最新核心、GUI、演出與續玩驗證；使用者視覺接受待試玩 |

| R17 | 敵我檢視與威脅範圍 | core/battle_rules.gd、ui/main.gd | 合法攻擊獨立比對與實際點選 |
| R18 | 鏡頭平移、定位、重置 | ui/hex_board.gd、ui/main.gd | 真實中鍵拖曳、F／Home、動畫中改尺寸 |
| R19 | 全畫面雙方剪影演出 | ui/combat_cinematic.gd | 雙向、箭矢、技能、擊倒、跳過、減少動態 |
| R20 | 戰鬥保存與備份恢復 | core/battle_save.gd | 損毀、無效狀態、失敗保護、16 組完整對戰續玩一致 |
| R21 | 偏好與規則說明 | core/preferences.gd、ui/main.gd | 音量／演出偏好重讀、F1 說明 |
| R22 | AI 繞路停滯修正 | core/battle_rules.gd | 原停滯位置、占位、成本、完全封閉測例 |

## 本次範圍外

未新增法師、範圍傷害、職業差異 AI、生存或回合限制任務、劇情、成長、裝備、永久死亡、網路連線、控制器或觸控操作。敵方保留四個能以兩職業實作的模板；未實作的法師模板不進入選單。

未自動讀取或遷移瀏覽器 localStorage。原版地圖 JSON 可手動匯入。Godot 專案與啟動器可執行，獨立桌面發佈包及 Web 匯出不在此次交付內。

## 系統分工

- core/hex_rules.gd：座標、地形、可達範圍與路徑。
- core/battle_rules.gd：攻擊合法性、部署驗證、勝敗、AI。
- core/catalog.gd 與 data/catalog.json：單一角色、職業、技能來源。
- core/battle_session.gd：部署、行動、回合與重開。
- core/data_store.gd：地圖、關卡、格式驗證與保存。
- ui/hex_board.gd：Control 自訂 2D 繪圖，與規則座標分離。
- ui/main.gd：介面、輸入、動畫協調與編輯工具。
- ui/game_audio.gd：本地合成音效。
- ui/combat_cinematic.gd：只讀戰鬥快照的全畫面演出。
- core/battle_save.gd：戰鬥快照驗證、保存及恢復。
- core/preferences.gd：音效與演出偏好。

保存路徑可透過 HEX_TACTICS_DATA_DIR 指定。Windows 啟動器預設使用專案 user_data；測試使用 D 槽獨立目錄。備份為 library.json.bak，原版不受影響。

## 比較與回退

原版 commit 為 20f89b2dce805302ad64d53a6cd3deeb3b7292fb。兩張地圖原樣複製。新版使用獨立 Git 檢查點；可用原版重新比較玩法，也可在新專案內回退程式版本。測試、日誌與使用者存檔排除於版本控制。

## 官方技術依據

- Godot AStar2D：https://docs.godotengine.org/en/stable/classes/class_astar2d.html
- Godot TileSet：https://docs.godotengine.org/en/stable/classes/class_tileset.html
- Godot Web 匯出：https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html

本版使用自訂 Dijkstra 以共用移動範圍與路徑計算，未依賴 TileMapLayer 或 AStar2D。Compatibility 與 GDScript 保留未來 Web 匯出選項，但未驗證 Web 包。

介面視窗樣式依據：[Godot AcceptDialog](https://docs.godotengine.org/en/stable/classes/class_acceptdialog.html)、[Godot Window](https://docs.godotengine.org/en/stable/classes/class_window.html)。
