# QuickConvert for macOS

<p>
  <a href="README.md"><img src="docs/assets/language-en.svg" alt="English" width="100" height="32"></a>
  <a href="README.zh-TW.md"><img src="docs/assets/language-zh-tw.svg" alt="繁體中文" width="112" height="32"></a>
</p>

在 Finder 右鍵選單中轉換圖片、音訊與文件。SwiftUI 原生介面，macOS 13 以上，提供 Apple Silicon 與 Intel 獨立安裝包。所有轉檔都在本機完成。

**0.3.5 分架構完整安裝包自帶轉檔引擎**：使用者無須 Homebrew、配置 PATH、安裝 FFmpeg、LibreOffice、Python 或 Rust。首次啟動不會下載引擎。公開 repo：[SHENGHUNGYU/QuickConvert](https://github.com/SHENGHUNGYU/QuickConvert)；正式公證 Release 尚未發布。

0.3.5 的 Finder 轉檔不顯示視窗或 Dock 圖示；佇列完成約 2 秒後自動退出。手動開啟 App 才顯示主介面。已實測 Finder 右鍵 Word → PDF 與背景程序退出。

| 電腦 | 安裝包 |
| --- | --- |
| Apple Silicon（M 系列） | `QuickConvert-0.3.5-arm64.dmg` |
| Intel Mac | `QuickConvert-0.3.5-x86_64.dmg` |

每包只含對應架構的 App、Finder 擴充、CLI、FFmpeg 與一套 LibreOffice，避免下載另一個 CPU 的 runtime。

## 快速開始

下載完整 DMG 的使用者只需把 App 拖入 Applications。以下是開發者從原始碼建置的方式，需要 Xcode 15 以上與其命令列工具。不需要下載任何 Swift 套件。

```sh
swift test
bash scripts/build.sh # 輕量開發版本，使用本機工具
open "build/$(uname -m)/Build/Products/Release/QuickConvert.app"

# 完整免配置安裝包：另需 Python 3、make、pkg-config 等開發工具
bash scripts/package.sh
# dist/QuickConvert-0.3.5-arm64.dmg
# dist/QuickConvert-0.3.5-x86_64.dmg
# 也可只做其中一包：bash scripts/package.sh arm64
```

也可直接開啟 `QuickConvert.xcodeproj`，選擇 QuickConvert scheme。`python3 scripts/generate_project.py` 可重建專案；新增來源檔案後請執行此指令。專案沒有第三方 Xcode 專案產生器依賴。

**未設定簽章團隊時，build.sh 產生本機預覽版**：主程式與 CLI 可用；Finder 擴充保留必要的 App Sandbox entitlement，可在系統設定啟用選單。0.3.1 已修正舊版預覽簽章漏掉 entitlement、導致系統拒絕註冊的問題。App Group 跨程序自訂設定共享及正式分發仍需有效團隊簽章驗收。請依 [開發與發布說明](docs/RELEASING.md) 設定。

主程式支援選取／拖放多個檔案、選擇目標格式、查看每個結果、取消與在 Finder 顯示輸出。Finder 入口會在背景喚起主程式，依序處理工作，不在 Finder 程序中執行轉檔，也不會自動開視窗、搶前景或顯示 Dock 圖示。若 App 已由使用者手動開啟，既有視窗會保留。

背景工作結束後約 2 秒自動退出；新工作抵達會取消退出。手動視窗關閉後，尚未完成的工作會在背景繼續，完成後退出。不安裝登入常駐服務、不定時掃描檔案。macOS 首次存取「下載項目／桌面／文件」等受保護位置仍可能要求系統授權，本機 ad-hoc 預覽版重新編譯／簽章後可能再次詢問；背景模式不會略過這些保護。通知權限只在設定中按「啟用系統通知」才詢問；Finder 轉檔只在已有權限時送出通知，通知服務不會阻擋轉檔，送達屬最佳努力。

轉檔期間仍需要 CPU、記憶體與磁碟空間，無法零資源消耗。檔案逐一處理、Swift worker 使用 utility 優先序、外部引擎 nice +10；FFmpeg 輸入／輸出 codec 要求最多 2 個執行緒、filter 1 個（非整個程序的總執行緒或 CPU 百分比上限）。每個檔案完成會釋放 autorelease 物件。外部程序等待結束使用 semaphore，最多每秒檢查 4 次取消狀態。Finder 擴充由 macOS 管理，閒置時只保留選單事件處理，仍有少量記憶體使用。

第一次建置單一架構會下載約 300 MB 官方來源／套件，編譯對應 C 引擎，並內嵌一套 Office runtime。建置另一架構時才下載另一套；後續使用 `build/`、`vendor/` 快取。這些是開發階段的下載，使用者執行 App 不需要下載。`QUICKCONVERT_ARCH=arm64` 或 `x86_64` 可指定 build.sh 的架構，未指定時使用本機架構。詳見 [內附引擎設計](docs/BUNDLED-ENGINES.md)。

0.3.5 修正 Office 轉 PDF 未載入 macOS 系統字型、導致中文消失或方框的問題。字型直接使用本機已安裝的版本；不下載、不複製或重新散布字型。缺少原稿指定字型時，仍可能使用替代字型並影響版面。

## 支援格式

| 類別 | 輸入 | 輸出 | 引擎 |
| --- | --- | --- | --- |
| 文件 | docx、xlsx、pptx、html、htm | PDF | 內附 LibreOffice 26.8.3 |
| 文字 | UTF-8 txt、md | PDF | CoreText，原生分頁 |
| 音訊 | mp3、wav、flac、m4a、aac、ogg | mp3、wav、m4a、flac | 內附 FFmpeg 9.0.2、LAME 3.100 |
| 圖片 | png、jpg、jpeg、webp、heic、tiff、tif | jpg、png、webp、pdf | ImageIO／CoreGraphics；WebP 使用內附 libwebp 1.6.0 |

0.3.4 補上瀏覽器錄音的 WebM／Opus 讀取支援；即使檔名為 `.wav`，也會由引擎依實際容器解析，不需手動改名。

同一次最多 500 個檔案，必須屬於同一類別；可混選同類別的不同輸入格式。選單隱藏任何會讓部分檔案變成「相同格式」的目標。資料夾、符號連結與不支援的檔案會被拒絕。每個輸入各產生一個輸出，不會合併 PDF。

- 輸出放在來源資料夾。完整轉檔後才以原子、不可覆寫的方式發布；若已有檔案或連結，依序使用 `name (1).pdf`、`name (2).pdf`。此保證也適用於同時執行的轉檔。
- 暫存資料夾位於來源資料夾，權限為 0700，成功、失敗或取消均會清理。程序被強制關閉／系統斷電時可能留下 `.quickconvert-*`，確認沒有工作執行後可刪除。
- 批次依序執行，個別失敗不會中止其他檔案。預設每個外部程序最多 10 分鐘。取消保留已完成的輸出。
- JPEG 會將透明區域填白；圖片套用 EXIF 方向。多頁 TIFF 與動態 WebP 的 MVP 行為為只轉第一頁／第一影格。Markdown 保留換行及基本行內語法；不支援完整網頁排版、遠端圖片或自訂 PDF 樣式。非 UTF-8 文字需先另存為 UTF-8。
- 完整版本已含目標編碼器；開發版本若使用其他 FFmpeg，須含 libmp3lame、aac、flac、libwebp。格式與版面保真仍受引擎與本機字型影響。不執行 Office 巨集或 Java 擴充。

## 引擎與開發版本

完整版本優先使用 App 內的工具，設定顯示「已內附」；按目前程序的 ARM／Intel 架構選擇 Office。無須以下安裝指令，也不會因舊設定或 PATH 而改用外部工具。

未內附引擎的開發版本才會偵測 `/opt/homebrew/bin`、`/usr/local/bin`、標準 LibreOffice app 位置與 PATH，或允許指定工具路徑。完整建置僅需另備 `pkg-config`（例如 `brew install pkgconf`），使用者不需要這些開發工具。

```sh
brew install ffmpeg
brew install --cask libreoffice
# 選用：專用 WebP 編碼器
brew install webp
```

安裝按鈕只會複製指令，使用者自行在終端機執行。安裝需要網路；轉檔不需要。未安裝外部工具仍可使用原生圖片與文字轉換。

## 離線與隱私

程式無遙測、更新檢查、上傳或遠端資源下載。FFmpeg／cwebp／LibreOffice 以 macOS `sandbox-exec` 禁止 IP 網路連線。LibreOffice 所需的 Unix socket 本機 IPC 可用，TCP／UDP（含 loopback）仍禁止。內附 FFmpeg 在編譯時也停用網路，只保留 `file,pipe` 協定。無法建立沙盒時會回報錯誤，不會退回可連網模式。Office 每次使用獨立設定檔，關閉巨集及自動更新外部文件連結，不會轉送至正在執行的 LibreOffice GUI。

原生 Markdown 只處理文字；HTML 交由禁止 IP 網路的 LibreOffice 解析。`sandbox-exec` 為 macOS 已棄用但目前仍提供的工具，未來系統若移除，需改成隔離的轉檔 helper。Finder 擴充啟用系統沙盒；主程式為站外分發 app，以便在來源資料夾輸出並執行內附工具。作業系統本身的 iCloud 同步不屬於程式網路行為。

## 命令列

```sh
# 完整 App 內的獨立執行檔
'/Applications/QuickConvert.app/Contents/Helpers/quickconvert' --bundled-only --check
'/Applications/QuickConvert.app/Contents/Helpers/quickconvert' --bundled-only --to pdf '/path/to/notes.md'

# 原始碼開發
swift run quickconvert --check
swift run quickconvert --to pdf '/path/to/notes.md'
swift run quickconvert --to mp3 '/path/to/one.wav' '/path/to/two.flac'
```

CLI 使用相同引擎；`--bundled-only` 禁止退回系統工具。回傳碼：0 成功、1 個別檔案失敗或內附檢查未通過、2 參數／選取錯誤。系統通知僅用於原生 app。

## 測試與驗收

`swift test` 涵蓋格式過濾、URL 驗證、設定儲存、並行發布衝突、原檔保留、PDF 分頁、實際音訊／圖片／Office 轉換、錯誤清理、逾時／取消／網路封鎖、批次失敗隔離及選單計算時間。另測內附工具優先序、架構選擇、越界符號連結與禁止退回系統工具。開發環境缺少引擎時會明確跳過整合測試；完整版本必須使用實際內附引擎驗證：

```sh
QUICKCONVERT_TEST_BUNDLE="$PWD/build/arm64/Build/Products/Release/QuickConvert.app" swift test --arch arm64
python3 scripts/verify_bundle.py build/arm64/Build/Products/Release/QuickConvert.app --architecture arm64
python3 scripts/smoke_bundle.py build/arm64/Build/Products/Release/QuickConvert.app
# 原生 Intel 機將 arm64 改為 x86_64；Apple Silicon 上的 Intel XCTest 指令見內附引擎文件。
```

LibreOffice 實際文件矩陣、具有效簽章的 Finder 選單／App Group、通知授權，以及 macOS 13 和 Intel 實機驗收，請依 [人工驗收清單](docs/ACCEPTANCE.md) 完成。編譯成 Intel 執行檔不等同 Intel 實機已測試。0.5 秒的選單計算會測量；包含系統啟動與冷啟動的時間仍需實機記錄。

本次已執行的測試與環境記錄見 [本機驗證紀錄](docs/VERIFICATION.md)。

## 專案結構

```text
App/                         SwiftUI 介面、工作佇列、通知
FinderExtension/             Finder 選單；轉檔交由主程式
Sources/QuickConvertCore/    格式、外部工具、原生引擎、批次與輸出
Sources/QuickConvertCLI/     獨立命令列入口
Tests/                       核心與引擎整合測試
Configuration/               Info.plist、沙盒與 App Group
scripts/                     Xcode 專案產生、ARM／Intel 獨立建置與 DMG
distribution/                Homebrew Cask 範本產生器
docs/                        發布與驗收說明
```

QuickConvert 自有原始碼採 MIT；內附 FFmpeg、LAME、libwebp、LibreOffice 保留各自授權。音訊／WebP 對應原始碼、建置腳本與授權隨 App 提供，Office 的原始碼取得方式與原廠授權也予以保留。詳見 [第三方聲明](distribution/THIRD-PARTY-NOTICES.md)。大型下載與引擎二進位檔不提交至 Git repo。
