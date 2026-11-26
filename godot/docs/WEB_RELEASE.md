# Web 發布

使用 Godot 4.6.3 官方 `web_nothreads_release.zip`，執行 `Export_Web.ps1 -Template <模板絕對路徑> -OutputDirectory <輸出目錄>`。腳本暫時設定模板路徑，完成或失敗皆還原 preset，不提交本機絕對路徑。

- Compatibility / WebGL 2、單執行緒，不需要 SharedArrayBuffer 跨來源隔離。
- Noto Sans TC 字型附 OFL 授權；Web 主題與 RichTextLabel 皆使用內附字型及 400 字重。
- 地圖 JSON 匯入使用瀏覽器選檔（1MB 上限），匯出使用下載；仍經地圖規則驗證。
- 遊戲資料保存於同來源瀏覽器 IndexedDB；清除網站資料、無痕模式或換裝置不會保留。舊版 JavaScript localStorage 與 Windows 存檔不會自動轉換。
- 目前以桌面 Chrome／Chromium 鍵鼠驗證，未宣稱觸控或所有手機瀏覽器可用。首次需下載約 57MB 未壓縮的引擎與遊戲資料；HTTP 壓縮可減少實際傳輸量。
- 匯出排除玩家 user_data、測試、文件、工具、Excel與備份，只包含執行資源。

發布目標：Vercel `game-hex-grid-4bj7`，既有網址 `https://game-hex-grid-4bj7.vercel.app/`。作品集 `my-portfolio` 只更新 Hex Grid 項目的說明、技術標籤與預覽。

Git 遊戲遠端沿用 `YusukeWu0903/game-hex-grid`，發布分支包含 `godot/` 原始碼與 `web/` 匯出包。舊 TypeScript 原碼保留於原路徑；Vercel 使用明確的靜態建置設定，不再執行舊版 Vite build。

官方依據：[Web 匯出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)、[JavaScriptBridge](https://docs.godotengine.org/en/stable/classes/class_javascriptbridge.html)、[FontVariation](https://docs.godotengine.org/en/stable/classes/class_fontvariation.html)。
