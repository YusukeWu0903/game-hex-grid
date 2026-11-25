# 已採用角色立繪

三張圖片以內建 image_gen 生成，使用者於 2026-11-25 明確採用三名造型後才匯入。原圖保存在 D:/Codex/generated_images/01a20b88-19f0-72c2-a0e2-ec5d82cad97d/。

完整提示與 SHA256：D:/Codex/visualizations/2026-11-25/hex-world-upgrade/art-prompts-and-adoption.json。

player_swordsman_01=艾爾、player_swordsman_02=羅伊、player_archer_01=琳恩。均保留原始 RGBA，沒有縮裁人物或武器。原圖預覽的隱藏 RGB 曾看似帶背景，Alpha 像素檢查與 Godot 實際演出證明背景區透明；最後採用使用者核准的原圖，兩次去背編輯候選未替換原造型。Godot 截圖在上述證據資料夾的 world-ui/*-duel.png。

圖像用於整張立繪的位移／震動演出，不是拆層骨架動畫或逐幀攻擊姿態。

## 米菈與雷昂正式採用（2026-11-25）

使用者明確採用職業輪廓版第二稿，並授權清理後入庫。player_mage_01.png 為尖帽、寬袖與懸浮法書的米菈；player_knight_01.png 為開面頭盔、全覆板甲、方盾低姿態的雷昂。使用內建 image_gen 定向去背，保留原生尺寸及 RGBA。生成式清理不保證無關像素完全一致，已目視檢查造型一致性。

來源、完整提示、SHA256 與遊戲截圖位於 D:/Codex/visualizations/2026-11-25/hex-portrait-integration/。原候選仍在 hex-mage-knight-candidates。清理圖原件在 D:/Codex/generated_images/01a20b88-19f0-72c2-a0e2-ec5d82cad97d/，檔名列於 adoption-and-prompts.json。

兩張新立繪按 Alpha 可見範圍快取繪製矩形，等比例放入 420×470 設計區並對齊腳底；不改原圖像素，也不每幀掃描 Alpha。已檢視左右翻轉、攻守、突進／復位與兩種視窗。鏡像測試將主角暫設為敵方僅供驗證，正式敵方仍使用其職業剪影。
