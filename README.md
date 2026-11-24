# Hex Tactics Godot

保留原版六角棋盤與兩職業的 Godot 2D 戰棋基準版。包含關卡選擇、部署、回合戰鬥、AI、勝敗結算、地圖與關卡編輯、JSON 匯入匯出及本地保存。

## 啟動

在 Windows 雙擊 Start_Game.cmd。啟動器使用上一層的 Godot_v4.6.3-stable_win64.exe；其他安裝位置可先設定 GODOT_BIN。也可用 Godot 4.6.3 開啟 project.godot，按 F6 執行 scenes/main.tscn，或 F5 執行整個專案。

這是可在 Godot 中直接執行的專案，尚未製作獨立遊戲執行檔或 Web 發佈包。

## 操作

1. 主選單選擇關卡，按「開始部署」。
2. 點角色後再點我方出生格，或使用「自動部署」；右鍵收回角色。
3. 開戰後點我方棋子或左側角色，點可達格移動。
4. 使用「攻擊」或技能按鈕，再點合法敵人。技能需足夠 MP。
5. 「待機」結束角色行動；「結束我方回合」確認後讓其餘角色待機。
6. 右鍵或 Escape 取消瞄準／選取。取消不待機，也不撤銷已完成的移動。
7. 滾輪縮放棋盤。上方可關閉音效或減少動態。

玩家普攻 4 傷害，敵方普攻 3；劍士重擊 10 MP／7 傷害，弓箭手強力射擊 15 MP／6 傷害。每場戰前全員恢復 HP／MP。

## 編輯與保存

地圖編輯先修改工作副本，按保存才寫入資料庫。匯入 JSON 先驗證並載入副本；無效地形、座標與出生點會被拒絕。地圖匯出保留原版格式。

關卡編輯使用同一份角色 ID 清單；出生點不足會禁止試玩。現階段只提供敵軍全滅／我方全滅規則。

啟動器將保存及日誌放在本專案 user_data，排除於版本控制。可用 HEX_TACTICS_DATA_DIR 指定其他目錄。保存會保留上一份 .bak。編輯地圖使關卡暫時不可玩時，關卡記錄仍保留，需補足出生點再試玩。

原瀏覽器 localStorage 不會自動搬移；可從原版匯出地圖 JSON 後在這裡匯入。

## 規格與維護

- docs/GAME_SPEC.md：已確認的目標玩法、數值、操作及驗收。
- docs/CURRENT_GAME_SPEC.md：原版調查與比較基準。
- docs/MIGRATION_REQUIREMENTS.md：移植需求、實作對應與範圍。
- docs/VALIDATION.md：驗證結果及仍需使用者確認的部分。
- data/catalog.json：職業、技能、玩家與敵人資料。
- core/：六角規則、戰鬥規則、回合模型與保存。
- ui/：棋盤、介面與音效。
- tests/：規則、整場模擬、保存與實際視窗流程測試。

## 測試

執行 powershell -ExecutionPolicy Bypass -File ./Run_Tests.ps1。預設 UI 測試會短暫開啟實際 Godot 視窗並截圖；可加 -HeadlessUI 只跑無畫面流程。測試使用隔離資料，截圖與日誌位於 D:/Codex/visualizations/2026-11-25/hex-tactics-godot 下的獨立 run 目錄。

目前支援 Windows 鍵鼠，最小視窗 1100×720。Compatibility 渲染器已在本機執行；Web、手機、控制器操作與其他平台尚未驗證。人工檢視截圖不等同使用者已接受畫面與操作。
