# 本機預覽版驗證紀錄

驗證日期：2026-11-18（Asia/Taipei）。此紀錄描述本次實際執行結果，不代表已完成公開發行或所有支援 OS 的實機驗收。

| 項目 | 結果 |
| --- | --- |
| 環境 | macOS 26.5.2、Apple Silicon、Xcode 26.5、Swift 6.3.2 |
| `swift test` | 14 項通過，0 失敗，無跳過；最後完整執行約 4.7 秒 |
| Office 整合 | DOCX 2 頁、XLSX 2 頁、PPTX 2 頁、HTML 1 頁；PDF 頁數與可搜尋文字均驗證 |
| 音訊整合 | WAV → MP3／M4A／FLAC，再轉回 WAV，均產生有效資料 |
| 圖片整合 | PNG → JPEG／PDF／WebP；WebP → PNG |
| 網路阻擋 | 沙盒內嘗試 loopback TCP 連線，確認回傳 EPERM；不以連線拒絕代替網路隔離證據 |
| Finder 格式計算 | 500 個檔案、重複 100 次，總計約 0.15 秒；僅涵蓋格式計算 |
| GUI | 實際開啟主程式／設定；從檔案對話框選取 notes.txt 並轉成 PDF；已有 notes.pdf 時產生 notes (1).pdf，顯示成功 |
| Universal 建置 | 主程式與 Finder appex 均含 arm64、x86_64 |
| 簽章與映像 | 本機 ad-hoc 簽章通過 `codesign --verify --deep --strict`；DMG 通過 `hdiutil verify` |
| 靜態設定 | Info.plist、entitlements、Xcode plist 格式及 shell／Python 語法檢查通過 |

測試工具：FFmpeg 4.2.2（本機 build 無 libwebp）、cwebp 1.3.2、LibreOfficeDev 26.8.0.0.alpha0。工具由本機環境提供，沒有打包至 app 或 DMG。正式發布仍需用穩定版引擎及最低支援系統驗收。

尚未驗證：有效團隊簽章的 Finder 擴充啟用與 App Group 跨程序設定同步、系統通知實際送達、公證／Gatekeeper、macOS 13、Intel 實機、所有輸入樣本與複雜版面、外接檔案系統，以及完整 UI 冷／暖啟動的 0.5 秒需求。詳見 [人工驗收清單](ACCEPTANCE.md)。

UI 測試期間發現通知授權等待會拖住轉檔；已將通知授權／送出改為獨立非同步工作，轉檔不再等待通知服務完成。之後重新建置並完成上述 GUI 轉檔。
