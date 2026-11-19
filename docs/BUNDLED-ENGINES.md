# 內附引擎設計

0.3.0 將 ARM／Intel 分成兩個安裝包，保留 SwiftUI、Swift 核心與可獨立執行的 Swift CLI，將 C 編譯的 FFmpeg 與文件 renderer 放入 App。每包只含一種架構，使用者無須配置環境。

```text
QuickConvert.app/Contents/
  MacOS/QuickConvert
  PlugIns/QuickConvertFinder.appex
  Helpers/
    quickconvert                 與安裝包相同架構的原生 CLI
    ffmpeg                       相同架構，靜態 LAME／libwebp
    LibreOffice-ARCH.app/        只附對應的 arm64 或 x86_64 runtime
  Resources/
    engines.lock.json
    runtime-manifest.json        此包的架構
    ThirdPartyLicenses/
    ThirdPartySources/           FFmpeg、LAME、libwebp 完整來源壓縮檔與建置紀錄
```

引擎與巢狀程式放在 Helpers 這個 code 位置。Office App 保留原始簽章；FFmpeg／CLI 在內嵌後簽章，最後重簽外層 QuickConvert。使用正式團隊時須保留 App Group entitlement。

## 解析與執行

`Dependencies.discover` 從執行檔所在 App 找到 Helpers，不使用工作目錄或硬編碼開發機位置。CLI 往上辨識包含自己的 App。Office 按目前程序的 `arm64`／`x86_64` 選擇，含 Rosetta 情況。

完整版本優先使用內附引擎，即使 PATH 或舊設定有其他 FFmpeg／cwebp。只在缺少內附引擎的開發版本退回系統工具。`.bundledOnly` 與 CLI 的 `--bundled-only` 完全關閉退回路徑，用於獨立運作驗證。

Finder 選單跨 XPC 邊界後不依賴 representedObject：用整數 tag 指定格式，在 action callback 取得 Finder 的 selectedItemURLs，重新驗證並建立請求。擴充明確指定自身所在的 App 來開啟請求 URL，避免其他安裝／開發副本截走工作。主程式在 AppDelegate 接收 URL，不依賴 SwiftUI 視窗是否已存在；同一請求僅處理一次。

0.3.4 內附 FFmpeg 啟用 Matroska／WebM demuxer 與 Opus decoder，用於瀏覽器錄音：部分錄音實際為 WebM／Opus，但下載名稱是 `.wav`。引擎直接依容器內容探測，不強制套用副檔名指定的 demuxer；未增加視訊解碼器或網路協定。合成 live WebM fixture 以中文 `.wav` 檔名測試 MP3 解碼、長度與原檔保留，打包驗證器也檢查相關 demuxer／decoder，避免誤帶舊快取。

轉檔仍經過 `ProcessRunner`。FFmpeg 停用網路編譯，僅啟用 file／pipe；程序沙盒禁止 IP 網路，允許 LibreOffice 所需的 Unix socket 本機 IPC。測試確認 loopback TCP 仍回傳 EPERM。無法建立隔離時不啟動引擎。

## macOS Office 字型

無視窗 Office 後端使用 Fontconfig，預設可能只看見內附西文字型，讀不到 macOS asset 中的中文字型。`OfficeFontConfiguration` 透過 CoreText 列出本機可讀的字型檔案目錄，每個工作產生獨立的 fonts.conf，僅對該次 Office 子程序設定 FONTCONFIG_FILE；不修改 DOCX 指定字型、不變更系統 Fontconfig、不複製或下載字型。系統字型缺失時仍可能替代字型，不能保證所有 Word 版面完全相同。

Fontconfig 掃描中繼資料放在使用者 Caches/QuickConvert/Fontconfig，避免每次重新掃描；快取目錄不可寫時改用工作目錄，完成後清理。快取不含文件內容，也不建立常駐字型程序。`ProcessRunner` 的環境覆寫僅作用於子程序，原有 IP 網路封鎖仍啟用。中文 DOCX／表格回歸測試會檢查 PDFKit 抽取的實際文字，避免只憑非空 PDF 與頁數判定成功。

## 來源與快取

`distribution/engines.lock.json` 記錄 FFmpeg 9.0.2、LAME 3.100、libwebp 1.6.0、LibreOffice 26.8.3 的 URL／SHA-256。官方來源：

- [FFmpeg releases](https://ffmpeg.org/releases/)
- [LAME releases](https://sourceforge.net/projects/lame/files/lame/3.100/)
- [libwebp 編譯文件](https://developers.google.com/speed/webp/docs/compiling)
- [LibreOffice 官方 stable 下載](https://download.documentfoundation.org/libreoffice/stable/26.8.3/)

下載先寫暫存，校驗後才加入快取；解壓拒絕越界路徑。以 macOS 13 部署目標編譯指定架構的 thin binary，不合併 universal。`prepare_engines.py --architecture arm64` 或 `x86_64` 只準備該架構，預設 `all` 準備兩者。停用自動外部依賴偵測、GPL、nonfree、視訊編碼器與不需要的格式；LAME／libwebp 使用私有 prefix 靜態連結。configure 指令寫入 `build-recipes.json`；原始碼沒有補丁。

`build/engine-downloads` 保存下載；`build/engines` 保存中間結果及 log；`vendor/engines/bin/ARCH` 保存對應的 FFmpeg，均不提交 Git。App 的 derived data 隔離在 `build/arm64`／`build/x86_64`，CLI 的 SwiftPM scratch path 也分離，不會互相覆寫。此流程可從鎖定來源重建，不宣稱跨 Xcode／SDK 的二進位位元完全相同。

## 驗證邊界

`verify_bundle.py` 依 runtime-manifest 及明確的 --architecture 檢查 App、Finder 擴充、CLI、FFmpeg 都只有指定架構，且恰好存在一套對應的 Office。另檢查來源校驗碼、授權、巢狀簽章、越界符號連結及動態依賴，禁止 Homebrew、使用者目錄或未解析的外部 dylib。Swift 系統 overlay 可位於 macOS dyld cache。

官方 Office 26.8.3 的**選用 Firebird 資料庫 intl plugin** 有未解析的 `@rpath/lib/libfbclient.dylib`。驗證器僅對這一個確切 plugin／load path 列出明確例外，不放行任意缺失函式庫。QuickConvert 不支援 Base／Firebird；DOCX／XLSX／PPTX／HTML 另做實際轉 PDF 測試，不宣稱 LibreOffice 所有功能皆可用。

`smoke_bundle.py` 將 App clone 至含中文／空白的新位置，使用只含 `/usr/bin:/bin` 的 PATH，移除動態函式庫環境變數，並以 `--bundled-only` 執行音訊、WebP、原生 PDF 與 Office PDF。AAC／OGG 使用合成正弦波 fixture，不依賴額外編碼器。可用 `--architecture x86_64` 在已具備 Rosetta 的 Mac 驗證 Intel 路徑；不會自行安裝 Rosetta。

Apple Silicon 上可先編譯 Intel 測試，再明確以 Intel XCTest runner 載入，避免 SwiftPM 的原生 testing helper 嘗試載入另一架構的 bundle：

```sh
swift build --build-tests --arch x86_64 --scratch-path .build/x86_64-tests
QUICKCONVERT_TEST_BUNDLE="$PWD/build/x86_64/Build/Products/Release/QuickConvert.app" \
  arch -x86_64 "$(xcrun --find xctest)" \
  .build/x86_64-tests/x86_64-apple-macosx/debug/QuickConvertPackageTests.xctest
```

0.2 的 universal App 約 1.6 GB、DMG 約 795 MB；0.3 每包只含一套 Office，以減少體積。裁剪 Office 檔案前仍必須重簽及做版面／字型／格式回歸。CI 分別在 macos-15（ARM）與 macos-15-intel 執行建置、整合與搬移測試，產物各自上傳。Cask 使用 arm／intel 對應的 URL 與 SHA-256。
