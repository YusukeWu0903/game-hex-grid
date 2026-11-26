# Windows 正式版與網頁試玩

Windows x86_64 使用 Godot 4.6.3 官方 windows_release_x86_64.exe 模板。執行 Export_Windows.ps1 -Template <模板路徑> -OutputDirectory <輸出資料夾>，將 HexTactics.exe 與 HexTactics.pck 一起壓縮。不可只發送 exe。

GitHub Releases 發布版本化 ZIP 與 SHA256SUMS.txt，作品集提供桌面下載及 Web 試玩入口。首次版本 v0.1.0（2026-11-26），仍持續開發中。Windows 套件未使用程式碼簽章。

Windows 發布版使用 Godot user:// 保存資料；Web 與編輯器存檔互相獨立，不會自動移轉。升級時解壓至新資料夾，勿覆蓋使用者資料。發布驗證使用 HEX_TACTICS_DATA_DIR 隔離測試。

官方匯出說明：https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html
