# Hex Tactics — Godot Web release

新版原始碼位於 `godot/`，執行用 WebAssembly 發布包位於 `web/`。舊版 TypeScript 原始碼保留在 `src/` 作為移植參照；正式站以 `vercel.json` 的靜態建置執行 Godot 版本。

Godot source commit: `7e07ef0`。完整關卡流程、Excel 劇情區段、四職業、裝備寶物、等級成長及回合回溯均包含。遊戲入口沿用 https://game-hex-grid-4bj7.vercel.app/ 。

本機預覽：`python -m http.server 8768 --directory web`。重新匯出請看 `godot/docs/WEB_RELEASE.md`。發布包不含玩家存檔與作者 Excel；Excel 在 Godot 原始碼內供離線編輯。

發佈分支保留舊站與 Godot 開發歷史；不強制改寫原 main。Vercel 對指定的 `game-hex-grid-4bj7` 專案部署此分支。
