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
