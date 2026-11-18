# 本機預覽版驗證紀錄

驗證日期：2026-11-18（Asia/Taipei）。此紀錄描述本次實際執行結果，不代表已完成公開發行或所有支援 OS 的實機驗收。

## 0.3.2 Finder 點擊到產檔

- 修正選單動作跨程序後讀不到 representedObject 而提前返回的派送方式：選單只傳整數格式 tag，在 Finder 保證有效的 action callback 重新取得 selectedItemURLs 並驗證請求。
- 明確開啟此擴充所在的 App，避免多份開發／安裝副本競爭 quickconvert URL scheme；主程式在 AppDelegate 接收 URL，涵蓋冷啟動或沒有可見視窗時的工作。移除重複的 view-level URL 處理。
- 實際從 Finder 對合成測試文件執行「QuickConvert → 轉換為 PDF」：冷啟動產生 menu-test.pdf，主程式已運行時再產生中文名稱 DOCX 的 PDF。沒有使用 CLI 代替選單點擊；沒有轉換或公開使用者的私人文件。
- 由 Finder 視窗與檔案系統同時確認輸出存在，再以 PDFKit 驗證 TXT PDF 1 頁、DOCX PDF 2 頁，內容可搜尋到 QuickConvert。輸出各出現一次，沒有因重複 URL handler 產生額外流水號檔案。
- 換上最終修正版後，另在 Downloads 的獨立測試資料夾以 Finder 右鍵轉換合成 DOCX，主程式顯示「完成 1 個，失敗 0 個」，Finder 中確實新增 PDF；未更動使用者原本的文件。
- 回歸測試模擬 Finder 重建的 NSMenuItem 不含 representedObject，僅保留 tag，確認所有格式可還原；非法 tag（含整數上下界）被拒絕。
- 本機 18 項單元／整合測試通過，0 失敗、無跳過。

## 0.3.1 Finder 選單修正

- 根因：預覽版 codesign 步驟未傳入 entitlements，導致 Finder 擴充缺少 `com.apple.security.app-sandbox`。系統 pkd 記錄拒絕理由為「plug-ins must be sandboxed」，PlugInKit 中沒有註冊項目。
- 修正：預覽版使用獨立的 Finder-Preview.entitlements，只要求必要的 App Sandbox；正式團隊仍使用原有 App Group 設定。打包驗證器讀取實際簽章內的 entitlement，缺少沙盒就失敗。
- 防回歸：原本 0.3.0 的壞簽章包被新驗證器拒絕；修正簽章的完整 App 通過內附引擎／架構／動態依賴／簽章檢查。
- 本機操作：先備份安裝的 App，修復簽章，再註冊並啟用該擴充。PlugInKit 顯示啟用，Finder 擴充程序成功執行；實際對 DOCX 右鍵確認出現「QuickConvert → 轉換為 PDF」。無須重啟 Finder或降低系統安全設定。
- 此驗證只證明本機 ad-hoc 預覽版能註冊及顯示選單，正式分發公證、跨程序 App Group 自訂設定共享仍需另行驗收。

## 0.3.0 ARM／Intel 分包

| 項目 | 結果 |
| --- | --- |
| ARM 安裝包 | QuickConvert-0.3.0-arm64.dmg，約 393 MiB；App 約 831 MiB |
| Intel 安裝包 | QuickConvert-0.3.0-x86_64.dmg，約 411 MiB；App 約 843 MiB |
| 架構隔離 | App、Finder 擴充、CLI、FFmpeg 均檢查為指定架構的 thin binary；每包只有一套對應的官方 Office runtime |
| ARM 測試 | 17 項單元／整合測試全數通過；使用實際 ARM 安裝包內的引擎 |
| Intel 測試 | 17 項全數通過；以 Rosetta 啟動 Intel XCTest runner，測試實際 Intel 安裝包的引擎，約 46 秒 |
| 搬移測試 | ARM 與 Intel／Rosetta 各完成 17 次轉換，只保留系統 PATH，使用 --bundled-only |
| Cask | 依 ARM／Intel 分別填入 URL 與 SHA-256；以實際 DMG 產生並通過 Ruby 語法檢查，尚未發布 |

CI 已改為 macos-15（ARM）與 macos-15-intel 兩個工作，各自建置、測試並上傳對應 DMG／SHA-256。遠端結果見 [GitHub Actions](https://github.com/SHENGHUNGYU/QuickConvert/actions)。本機 Intel 測試透過既有 Rosetta，不能代替 Intel 實機與 macOS 13 驗收。兩包均為 ad-hoc 本機預覽版，正式簽章／公證仍待擁有者設定。

## 0.2 歷史驗證

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
