# 開發、簽章與發布

## Finder 擴充開發

1. 開啟 `QuickConvert.xcodeproj`，在 QuickConvert 與 QuickConvertFinder 兩個 target 選擇相同 Apple Developer Team。
2. 兩者的 App Groups entitlement 使用 `$(TeamIdentifierPrefix)com.quickconvert.shared`。macOS 使用 Team ID 前綴的群組命名；建置後確認兩個 Info.plist 的 QuickConvertAppGroup 與 entitlements 完全相同。
3. 以有效簽章建置，將 app 放至 `/Applications`，開啟主程式後按「啟用 Finder 選單」。使用者在系統設定啟用 Finder 擴充。擴充不需要執行外部工具或取得來源目錄寫入權限。
4. 改變設定勾選並重新開啟右鍵選單，驗證兩程序看到相同 App Group 設定。若群組識別碼或 Team 改變，原設定不會自動搬移。

```sh
DEVELOPMENT_TEAM=YOURTEAMID bash scripts/build.sh
```

沒有團隊時 `bash scripts/build.sh` 建置本機架構 App 後進行 ad-hoc 簽章，可用 QUICKCONVERT_ARCH=arm64 或 x86_64 指定。Finder 擴充必須使用 `Configuration/Finder-Preview.entitlements` 保留 App Sandbox；不能只做不帶 entitlements 的 ad-hoc 簽章，否則 pkd 會以「plug-ins must be sandboxed」拒絕註冊。此模式可在本機啟用選單，但不帶正式 App Group 權限，跨程序自訂設定共享仍待正式簽章驗收。

若選單未出現，先開啟 App，在「啟用 Finder 選單」的系統設定中勾選 QuickConvert Finder。開發診斷可用 `pluginkit -m -A -D -vv -i com.quickconvert.app.finder` 檢查註冊與啟用狀態。只有註冊失效時才重新註冊安裝於 Applications 的擴充，避免其他開發副本搶佔；不要清空整個 PlugInKit 資料庫或重設其他 App 的擴充設定。

若 Xcode 出現 DVTDownloads／IDESimulatorFoundation 元件載入錯誤，可先執行 `xcodebuild -runFirstLaunch` 完成 Xcode 元件安裝，再重試。若仍失敗，需修復本機 Xcode；不應修改專案來掩蓋工具鏈問題。

## DMG

```sh
bash scripts/package.sh
# dist/QuickConvert-0.3.4-arm64.dmg
# dist/QuickConvert-0.3.4-x86_64.dmg
# 只打包一個架構：bash scripts/package.sh arm64
```

每個產物含完整 App、Applications 捷徑、英文與繁體中文 README、語言切換按鈕圖檔、貢獻與開發文件、第三方聲明及 MIT License。App、Finder、FFmpeg、CLI 都是對應架構的 thin binary，只附一套 LibreOffice、第三方授權與 FFmpeg／LAME／libwebp 對應原始碼。使用者無須配置環境；開發建置需要 Python 3、make、pkg-config。未設定 DEVELOPMENT_TEAM 時只供本機預覽。細節見 [內附引擎](BUNDLED-ENGINES.md)。

## 公開發布

原始碼已位於公開倉庫 https://github.com/SHENGHUNGYU/QuickConvert 。公開安裝包仍需要擁有者的 Apple Developer ID 與 notarization 憑證；本專案不包含這些帳號資料。

1. 將 bundle ID 調整為擁有者管理的識別碼，完成同團隊 App Group 與 Developer ID 設定。
2. 在 Release 設定選擇 `Developer ID Application` 憑證，保留 hardened runtime。依由內至外順序驗證 extension 與 app 的簽章；以 Developer ID 簽章建置 DMG，驗證 `codesign --verify --deep --strict`。
3. 使用 Keychain 中已設定的 notarytool profile：

   ```sh
   for arch in arm64 x86_64; do
     xcrun notarytool submit "dist/QuickConvert-0.3.4-$arch.dmg" --keychain-profile YOUR_PROFILE --wait
     xcrun stapler staple "dist/QuickConvert-0.3.4-$arch.dmg"
     xcrun stapler validate "dist/QuickConvert-0.3.4-$arch.dmg"
     spctl --assess --type open --context context:primary-signature --verbose "dist/QuickConvert-0.3.4-$arch.dmg"
   done
   ```

4. 完成 docs/ACCEPTANCE.md 的正式簽章與實機項目，建立版本 tag 與 GitHub Release，附上 notarized DMG、SHA-256、已知限制與安裝說明。
5. 用真實 release URL 與最終 DMG 產生 Cask：

   ```sh
   python3 distribution/make_cask.py --version 0.3.4 \
     --arm64-dmg dist/QuickConvert-0.3.4-arm64.dmg \
     --x86_64-dmg dist/QuickConvert-0.3.4-x86_64.dmg \
     --repository https://github.com/SHENGHUNGYU/QuickConvert \
     --output dist/quickconvert.rb
   ```

6. 在擁有者的 Homebrew tap 提交 `Casks/quickconvert.rb`，執行 `brew audit --cask --online quickconvert` 與安裝／移除驗證。符合 Homebrew 的接受條件後再另提 Homebrew Cask PR。不要發布含示例帳號或虛構 checksum 的 Cask。

本機建置完成不代表已公證、上架或通過公開發行驗收。
