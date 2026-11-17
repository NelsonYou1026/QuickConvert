# 0.2 本機預覽版驗證紀錄

驗證日期：2026-11-18（Asia/Taipei）。此紀錄描述本次實際執行結果，不代表已完成公開發行或所有支援 OS 的實機驗收。

| 項目 | 結果 |
| --- | --- |
| 環境 | macOS 26.5.2、Apple Silicon、Xcode 26.5、Swift 6.3.2 |
| `swift test` | 17 項通過，0 失敗，無跳過；使用 QUICKCONVERT_TEST_BUNDLE 強制測試實際內附引擎，約 9 秒 |
| Office 整合 | DOCX 2 頁、XLSX 2 頁、PPTX 2 頁、HTML 1 頁；PDF 頁數與可搜尋文字均驗證 |
| 音訊整合 | WAV → MP3／M4A／FLAC，再轉回 WAV；另測 AAC／OGG → MP3 |
| 圖片整合 | PNG → JPEG／PDF／WebP；WebP → PNG |
| 網路阻擋 | 沙盒內嘗試 loopback TCP 連線，確認回傳 EPERM；不以連線拒絕代替網路隔離證據 |
| Finder 格式計算 | 500 個檔案、重複 100 次，總計約 0.15 秒；僅涵蓋格式計算 |
| GUI | 前版 0.1 已驗證主程式／設定與 notes.txt → PDF，自動產生 notes (1).pdf；0.2 UI 已建置但尚未重做完整 GUI 操作驗收 |
| Universal 建置 | 主程式、Finder appex、CLI、FFmpeg 均含 arm64、x86_64；Office 附帶兩個架構的官方 runtime |
| ARM 搬移測試 | 完整 App clone 至含中文／空白的新位置，只保留系統 PATH，以 --bundled-only 完成 17 次轉換 |
| Intel 路徑 | 已具備 Rosetta 的 Mac 上以 x86_64 CLI 執行相同 17 次搬移轉換，使用 Intel Office；不是 Intel 實機測試 |
| 動態依賴 | FFmpeg 僅引用 macOS 系統函式庫；包內 Mach-O 掃描無 Homebrew／使用者目錄載入路徑；一個原廠選用 Firebird plugin 有明列例外，見 BUNDLED-ENGINES.md |
| 簽章與映像 | 本機 ad-hoc 簽章通過 `codesign --verify --deep --strict`；DMG 通過 `hdiutil verify` |
| 靜態設定 | Info.plist、entitlements、Xcode plist 格式及 shell／Python 語法檢查通過 |

內附引擎：FFmpeg 9.0.2、LAME 3.100、libwebp 1.6.0、LibreOffice 26.8.3.1。音訊／WebP 由鎖定原始碼編譯成 universal binary；Office 由官方 DMG 校驗後保留原始簽章與完整資源。App 約 1.6 GB；使用者無須另外安裝任何轉檔工具。第三方授權、音訊／WebP 原始碼與建置紀錄隨 App 提供。

尚未驗證：有效團隊簽章的 Finder 擴充啟用與 App Group 跨程序設定同步、系統通知實際送達、公證／Gatekeeper、macOS 13、Intel 實機、所有輸入樣本與複雜版面、外接檔案系統，以及完整 UI 冷／暖啟動的 0.5 秒需求。詳見 [人工驗收清單](ACCEPTANCE.md)。

0.1 UI 測試曾發現通知授權等待會拖住轉檔，已將通知流程解耦。0.2 實測發現 Office 需要 Unix socket 本機 IPC，已精確允許；loopback TCP 仍受測試確認封鎖。所有引擎都保持 IP 網路隔離。
