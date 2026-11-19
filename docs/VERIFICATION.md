# 本機預覽版驗證紀錄

驗證日期：2026-11-18、2026-11-19（Asia/Taipei）。此紀錄描述本次實際執行結果，不代表已完成公開發行或所有支援 OS 的實機驗收。

## 0.3.5 Office 中文字型修正（2026-11-19）

- 已從實際回報重現無視窗 Office 只載入內附西文字型、中文內容消失或變成方框的問題。系統已有相應 macOS 字型，問題在 Fontconfig 沒有掃描 macOS font asset 目錄。
- 新增 CoreText → Fontconfig 橋接，列出本機實際存在的字型檔案目錄並產生工作專用 fonts.conf，僅透過該 Office 子程序的 FONTCONFIG_FILE 傳入。不修改原稿字型設定、不下載或複製字型、不更動全域環境；保留 IP 網路封鎖。
- 字型掃描中繼資料使用本機 Caches/QuickConvert/Fontconfig；無法寫入時回退至工作暫存目錄。沒有背景掃描或常駐字型程序。
- 使用合成繁體中文段落／英數字／表格 DOCX，舊安裝版會輸出無中文的 PDF；新回歸測試直接以 PDFKit 檢查標題、段落和表格文字，另測試子程序環境覆寫不會污染主程序。ARM 原生及 Intel（Rosetta）各 23 項核心測試通過。
- 兩架構搬移完整 App 後各通過 19 次離線轉換，新增中文 DOCX 案例。兩份 DMG 映像與 SHA-256 檢查通過。
- 已用實際打包的 0.3.5 CLI 重新轉換回報原稿，逐頁檢查 PNG，確認中文、底線、簽名欄可讀，且按版面抽取的中文序列與原稿相符，沒有遺失原稿可見字元。修正版另存，原 DOCX／舊 PDF 保留；原稿、修正版及 QA 圖片均未提交公開倉庫。
- 字型不存在或不同 Office 排版引擎造成的版面差異仍屬既有驗收限制；此修正不宣稱所有 Word 文件皆能像素一致。

## 0.3.4 瀏覽器錄音轉 MP3 修正

- 已重現副檔名 `.wav`、實際容器為 WebM／Opus 的錄音，在原內附 FFmpeg 回報 Invalid data found when processing input。真正的 PCM WAV 原本可轉換，問題在裁剪引擎缺少 Matroska／WebM demuxer。
- ARM／Intel 的內附 FFmpeg 均已由鎖定原始碼重建，啟用 Matroska demuxer 並保留 Opus decoder。不依副檔名強制解碼，不需要使用者更名，也未新增網路協定或視訊解碼器。引擎準備腳本的雜湊會使舊快取失效。
- 新增合成一秒正弦波的 live WebM／Opus fixture，測試時複製為中文 `.wav` 檔名；回歸測試確認舊引擎失敗、修正引擎能產生長度合理且可由 AVFoundation 解碼的 MP3、保留來源位元組及清除工作目錄。公開 fixture 不包含使用者錄音。
- 本機已更新為 0.3.4。對原本失敗的錄音實際執行 Finder → QuickConvert → 轉換為 MP3，macOS 重新要求 Downloads 權限後由使用者允許，成功於原資料夾產生 MP3；FFprobe 驗證 MP3 音軌，與獨立隔離引擎驗證輸出一致。主程式及 FFmpeg 完成後均自行退出。沒有上傳使用者原檔或輸出。
- ARM 原生及 Intel（本機 Rosetta）各 21 項核心測試通過；兩架構搬移完整 App 後各通過 18 次離線轉換，包含新瀏覽器錄音案例。兩份 DMG 校驗及映像檢查通過。
- 0.3.3 的 CI 原有優先序測試以絕對 nice ≥ 10 判定，遠端觀察值與本機不同。改用測試時編譯的原生 C probe 直接查詢子程序，並以父程序繼承值 +10（最高 PRIO_MAX）判定，不假設執行環境的初始 nice 為零；CI 在準備引擎前先執行此檢查。正式遠端結果以 GitHub Actions 為準。

## 0.3.3 背景執行與資源回收

- 以 LSUIElement 起始，移除自動建立 WindowGroup 的 App 生命週期；只有一般開啟／重新開啟 App 才建立 SwiftUI hosting window 並切換為一般 Dock App。Finder URL 請求直接進佇列，不建立視窗。
- 佇列清空且無手動視窗時，單次可取消的 2 秒寬限後退出；新請求與手動開窗會取消退出。沒有登入常駐或定期閒置輪詢。背景轉檔不詢問通知授權；設定新增明確授權按鈕，通知以最佳努力送出。
- worker utility 優先序、每次一檔、檔案之間清理 autorelease pool；外部程序 utility QoS 與 nice +10。FFmpeg codec threads=2、filter_threads=1，並非整體 CPU／記憶體硬上限。ProcessRunner 改用終止 semaphore，取消檢查最多 4 次／秒，仍保留 timeout、SIGTERM 寬限與 SIGKILL。
- 實際在 Downloads 的獨立合成測試資料夾，從 Finder 右鍵轉換中文 DOCX；Finder 保持前景，未出現 QuickConvert 視窗，產生 2 頁可搜尋 QuickConvert 的 PDF。程序記錄確認完成通知送交服務後約 2 秒退出，主程式與 Office 子程序均消失。
- 最終版本另從 Finder 同時選取暫存測試資料夾內的中文 DOCX 與 TXT，實際右鍵批次產生兩份 PDF；原地出現輸出且主程式自行退出，未顯示主視窗。手動開啟主介面、開啟及關閉 SwiftUI 設定 sheet、讀取內附引擎狀態，以及關閉主視窗後退出均可用。
- 重新簽章後補測 Downloads 的原生 TXT 讀取，macOS 因 ad-hoc code requirement 改變再次要求 kTCCServiceSystemPolicyDownloadsFolder 授權，該次批次停在讀檔等待；已終止該合成測試工作，再以不需此授權的獨立暫存資料夾驗證上述批次。沒有修改 TCC、略過系統保護或替使用者授權。受保護位置首次存取可能仍需使用者回應系統授權，無法保證完全無系統提示。
- ARM 原生與 Intel（Rosetta）核心測試各 20 項通過，新增真實子程序 nice 值與啟動後取消測試；兩架構搬移完整 App 後各通過 17 次離線轉換。
- 此變更不宣稱轉檔零 CPU／記憶體使用。Finder 擴充由 macOS 管理，仍可能常駐少量記憶體；所有 OS／Intel 實機與正式簽章驗收仍見既有清單。

API 依據：[Apple 背景 App activation policy](https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/accessory)、[Apple 預設啟動辨識](https://developer.apple.com/documentation/appkit/nsapplication/launchisdefaultuserinfokey)、[FFmpeg 執行緒設定](https://ffmpeg.org/ffmpeg.html)。Finder 擴充為 sandbox 程序，沒有使用會被系統忽略的 OpenConfiguration.arguments 判斷啟動模式。

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
