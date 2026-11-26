# 大型地圖效能紀錄 — 2026-11-25

測試：Godot 4.6.3、Compatibility、NVIDIA RTX 3060、1440×900 視窗；半徑 24／1,801 格，種子 20261125，山水目標 45%。每場景 180 個影格，60 FPS 上限。只量測地圖編輯與鏡頭，不能推論整場 AI／所有硬體。

| 場景 | 原逐格繪製 P95 | 最終 P50 | 最終 P95 | 最終最差影格 |
|---|---:|---:|---:|---:|
| 靜止 | 17.705 ms | 16.684 ms | 17.021 ms | 17.910 ms |
| 一般比例平移 | 69.271 ms | 16.675 ms | 16.981 ms | 17.934 ms |
| 0.45 倍縮小平移 | 191.012 ms | 16.689 ms | 17.104 ms | 21.890 ms |

縮小平移的最高 Draw Calls：7,302 → 183。最終 Godot 靜態記憶體最高 70.13 MiB，VRAM 約 18.62 MiB；不含 Windows 程序總配置，也不含首次載入三名立繪的額外紋理。最大地圖生成 851 ms，單次結果而非保證上限。

改善順序：可視地形裁切與小地圖快取 → 共用原生烘焙圖集 → 地形節點保留指令、只變換鏡頭 → 動態覆蓋層只掃描有提示的格子。對照資料沒有刪除。

實際影格間隔由 Time.get_ticks_usec 在 process_frame 間取樣。Performance.TIME_PROCESS 顯示值可能包含等待或較慢更新，不將它當作純 CPU 使用率。沒有量測 GPU 使用率、功耗或長時間記憶體洩漏；目前不能宣稱已完成這些驗證。

重測腳本：tests/profile_world.gd。先把 HEX_TACTICS_TEST_DIR 與 HEX_TACTICS_DATA_DIR 設為 D 槽隔離資料夾，再執行 Godot --path D:/Project/hex-grid-godot --script res://tests/profile_world.gd --resolution 1440x900。

證據：D:/Codex/visualizations/2026-11-25/hex-world-upgrade/performance-before-atlas.json、performance-atlas-only.json、world-ui/performance.json 及 performance.png。後續有新地形、粒子或大量單位時應重跑；不要只看靜止 FPS。

## 最大地圖邏輯抽樣

profile_world_logic.gd：同種子、3 對 3 初始部署，敵方規劃 59.919／57.019／58.410 ms，個別威脅範圍 0.903／0.941／1.075 ms；序列化戰鬥快照 26,358 bytes。這是單次抽樣，非 P95，也非完整大地圖戰局。規劃為同步、每名敵人行動前執行一次，仍會有約 60 ms 的瞬間停頓；後續若擴軍應加入分幀／背景規劃或進一步減少搜尋，不應宣稱敵方回合全程 60 FPS。證據 world-ui/performance-logic.json。

## RPG 擴充後複測（2026-11-25）

RTX 3060、Compatibility、1440×900、60 FPS 上限，最大半徑 24 地圖：鏡頭一般平移 P95 16.875 ms、縮小平移 16.859 ms，最多 211 draw calls；Godot 靜態記憶體約 70.27 MiB，VRAM 約 18.65 MiB。單次生成 897 ms。靜態記憶體不是整個程序工作集；本測試是地圖編輯器鏡頭情境，不代表所有戰鬥或低階裝置。

最大地圖合成 200 個回合節點：歷史額外靜態記憶體約 2.88 MiB、捕捉 P95 0.086 ms、回溯 1.406 ms、存檔 446,567 bytes、序列化 37.128 ms。讀檔驗證共享靜態地圖檢查後由 3255.64 ms 降至 226.414 ms；各節點單位與背包仍逐一驗證。此為合成歷史測試，並非實玩 200 回合。

每名敵軍規劃約 42–43 ms，同步規劃仍可能有短暫停頓。未量測長時間洩漏、功耗或其他硬體。原始資料：D:/Codex/visualizations/2026-11-25/hex-rpg-expansion/performance.json 與 performance-rpg.json。

編隊／任務擴充後複測（2026-11-26）：最大地圖合成200回合歷史額外2.876MiB，捕捉P95 0.091ms、回溯1.478ms、驗證267.469ms、快照446567 bytes；每名敵人規劃約46–48ms。與前輪同樣為本機合成歷史，非長時間實玩。任務條件在行動／回合事件判定，區域標示沿用有限提示格繪製；不新增每幀尋路。這輪未重測FPS，不沿用舊數據宣稱新FPS。原始資料在 D:/Codex/visualizations/2026-11-26/hex-squad-objectives/final-verification/performance-rpg.json。

等級與敵軍立繪整合後複測（2026-11-26）：1,801 格、200 回合合成歷史額外 3.075 MiB（增加約 0.20 MiB），捕捉 P95 0.097 ms、回溯 1.552 ms、序列化 41.038 ms、含歷史驗證 279.636 ms、快照 475,528 bytes；每名敵人規劃 45–47 ms。存檔驗證及同步 AI 仍可能造成短暫停頓。

同機 RTX 3060、OpenGL Compatibility、1440×900 地圖編輯器取樣：閒置／一般平移／縮小平移各 180 幀，中位幀時間均約 16.67 ms（60 FPS 上限）；P95 為 16.842／16.711／16.710 ms，Godot 靜態記憶體最高 71.37 MiB，顯示記憶體約 16.37 MiB。生成半徑 24 地圖約 1.093 秒。這是地圖場景短取樣，並非全戰役／所有硬體／功耗或長時間洩漏驗證，也不含全部立繪紋理載入後的記憶體。

等級只在事件／建立單位時更新；立繪紋理及 Alpha 範圍僅首次快取。證據：D:/Codex/visualizations/2026-11-26/hex-level-system/performance.json、performance-rpg.json。
# 2026-11-26 對話系統短測

`tests/profile_story.gd` 在 RTX 3060、Compatibility renderer、60 FPS 上限下採樣 180 幀：中位 16.681ms、P95 16.856ms、Godot 靜態記憶體最大 71.75MiB、視訊記憶體 24.52MiB。本次只有一個角色立繪快取，結束時快取與 TextureRect 引用皆已清空。這是短測，未宣稱長時間無洩漏或各硬體一致。

示範 5 事件的條件判斷 10000 次平均約 10–12µs；只在戰況更新邊界呼叫，不在每幀掃描。200 回合合成歷史約 3.21MiB、快照 481357 bytes、回溯 2.94ms、驗證 374.67ms；此項與 UI 回歸同期執行，不用來比較前後 CPU 速度。同步 AI 規劃本次 63–67ms，仍有既存的短暫阻塞風險；對話本身未解決此項。

原始結果：`D:/Codex/visualizations/2026-11-26/hex-dialogue/performance-story.json` 與 `performance-rpg.json`。
