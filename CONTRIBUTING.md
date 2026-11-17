# 參與開發

請先閱讀 README 與 docs/ACCEPTANCE.md。需要 macOS 13 以上、Xcode 15 以上；`swift test` 可驗證不依賴簽章的核心。

1. 在 `Sources/QuickConvertCore` 實作轉換，保持 Finder 回呼僅做記憶體內格式過濾。
2. 每個外部工具都必須經過 `ProcessRunner`，使用參數陣列，禁止 shell 字串拼接與網路。
3. 不得直接覆寫來源或目的地。先寫暫存，驗證輸出，再使用 `OutputPublisher`。
4. 對轉檔正確性、批次隔離與資料安全行為加入有意義的回歸測試。UI 微調不需要測試實作細節。
5. 執行 `swift test`、`python3 scripts/generate_project.py` 與 `bash scripts/build.sh`。新增檔案後更新 Xcode 專案；不要提交 build、dist 或個人簽章資料。

PR 請描述使用者可觀察的變更、驗證結果、需要的外部工具及尚未完成的實機驗收。任何引入網路、變更授權或附帶第三方二進位檔的變更，都必須明確說明原因與影響。
