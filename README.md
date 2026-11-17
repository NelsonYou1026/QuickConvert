# QuickConvert for macOS

在 Finder 右鍵選單中轉換圖片、音訊與文件。SwiftUI 原生介面，macOS 13 以上，Apple Silicon／Intel 通用執行檔。所有轉檔都在本機完成。

## 快速開始

需要 Xcode 15 以上與其命令列工具。不需要下載任何 Swift 套件。

```sh
swift test
bash scripts/build.sh
open build/Build/Products/Release/QuickConvert.app
```

也可直接開啟 `QuickConvert.xcodeproj`，選擇 QuickConvert scheme。`python3 scripts/generate_project.py` 可重建專案；新增來源檔案後請執行此指令。專案沒有第三方 Xcode 專案產生器依賴。

**未設定簽章團隊時，build.sh 產生本機預覽版**：可使用主程式與 CLI，但 Finder 擴充的沙盒、App Group 與選單設定共享需要有效的同團隊簽章。請依 [開發與發布說明](docs/RELEASING.md) 設定。首次使用在程式內按「啟用 Finder 選單」，由使用者在系統設定勾選 QuickConvert Finder。不要以未簽章預覽版判定 Finder 整合驗收結果。

主程式支援選取／拖放多個檔案、選擇目標格式、查看每個結果、取消與在 Finder 顯示輸出。Finder 入口會在背景喚起主程式，依序處理工作，不在 Finder 程序中執行轉檔。

## 支援格式

| 類別 | 輸入 | 輸出 | 引擎 |
| --- | --- | --- | --- |
| 文件 | docx、xlsx、pptx、html、htm | PDF | 本機 LibreOffice |
| 文字 | UTF-8 txt、md | PDF | CoreText，原生分頁 |
| 音訊 | mp3、wav、flac、m4a、aac、ogg | mp3、wav、m4a、flac | 本機 FFmpeg |
| 圖片 | png、jpg、jpeg、webp、heic、tiff、tif | jpg、png、webp、pdf | ImageIO／CoreGraphics；WebP 輸出用 cwebp 或含 libwebp 的 FFmpeg |

同一次最多 500 個檔案，必須屬於同一類別；可混選同類別的不同輸入格式。選單隱藏任何會讓部分檔案變成「相同格式」的目標。資料夾、符號連結與不支援的檔案會被拒絕。每個輸入各產生一個輸出，不會合併 PDF。

- 輸出放在來源資料夾。完整轉檔後才以原子、不可覆寫的方式發布；若已有檔案或連結，依序使用 `name (1).pdf`、`name (2).pdf`。此保證也適用於同時執行的轉檔。
- 暫存資料夾位於來源資料夾，權限為 0700，成功、失敗或取消均會清理。程序被強制關閉／系統斷電時可能留下 `.quickconvert-*`，確認沒有工作執行後可刪除。
- 批次依序執行，個別失敗不會中止其他檔案。預設每個外部程序最多 10 分鐘。取消保留已完成的輸出。
- JPEG 會將透明區域填白；圖片套用 EXIF 方向。多頁 TIFF 與動態 WebP 的 MVP 行為為只轉第一頁／第一影格。Markdown 保留換行及基本行內語法；不支援完整網頁排版、遠端圖片或自訂 PDF 樣式。非 UTF-8 文字需先另存為 UTF-8。
- FFmpeg 版本須包含目標編碼器（MP3：libmp3lame、M4A：aac、FLAC：flac）。若 FFmpeg 缺少 libwebp，可另外安裝 cwebp。格式與版面保真仍受引擎與本機字型影響。

## 外部工具

設定介面會偵測 `/opt/homebrew/bin`、`/usr/local/bin`、標準 LibreOffice app 位置與程序的 PATH；從 Finder 開啟的程式通常不會繼承終端機的 PATH。可用「選擇路徑」指定執行檔。

```sh
brew install ffmpeg
brew install --cask libreoffice
# 選用：專用 WebP 編碼器
brew install webp
```

安裝按鈕只會複製指令，使用者自行在終端機執行。安裝需要網路；轉檔不需要。未安裝外部工具仍可使用原生圖片與文字轉換。

## 離線與隱私

程式無遙測、更新檢查、上傳或遠端資源下載。FFmpeg／cwebp／LibreOffice 以 macOS `sandbox-exec` 禁止網路存取；FFmpeg 額外僅允許 `file,pipe` 輸入協定。無法建立沙盒時會回報錯誤，不會退回可連網模式。Office 每次使用獨立設定檔，關閉巨集及自動更新外部文件連結，不會轉送至正在執行的 LibreOffice GUI。

原生 Markdown 只處理文字；HTML 交由禁止網路的 LibreOffice 解析。`sandbox-exec` 為 macOS 已棄用但目前仍提供的工具，未來系統若移除，需改成隔離的轉檔 helper。Finder 擴充啟用系統沙盒；主程式為站外分發 app，以便在來源資料夾輸出並執行使用者安裝的工具。作業系統本身的 iCloud 同步不屬於程式網路行為。

## 命令列

```sh
swift run quickconvert --check
swift run quickconvert --to pdf '/path/to/notes.md'
swift run quickconvert --to mp3 '/path/to/one.wav' '/path/to/two.flac'
```

CLI 使用相同引擎，回傳碼：0 成功、1 個別檔案失敗、2 參數／選取錯誤。系統通知僅用於原生 app。

## 測試與驗收

`swift test` 涵蓋格式過濾、URL 編解碼與拒絕無效請求、設定儲存、多程序發布衝突、原檔保留、文字 PDF 分頁、空文件、圖片轉換、錯誤清理、外部工具逾時／取消／網路封鎖、批次失敗隔離及選單計算時間。包含實際 DOCX、XLSX、PPTX、HTML 的 LibreOffice 整合測試；未安裝 LibreOffice 或 FFmpeg 時，對應測試會明確跳過。WebP 整合需要 cwebp 或具 libwebp 的 FFmpeg。

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
scripts/                     Xcode 專案產生、universal 建置與 DMG
distribution/                Homebrew Cask 範本產生器
docs/                        發布與驗收說明
```

以 MIT 授權散布原始碼，未附帶 FFmpeg、LibreOffice 或其他第三方二進位檔。使用者另行安裝的工具依各自授權使用；若未來要打包第三方引擎，必須先依實際 build 的授權、連結與散布方式進行授權審查，不能只靠改動本專案 LICENSE 宣告。
