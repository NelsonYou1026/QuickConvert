import SwiftUI

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var copied = ""

    var body: some View {
        Form {
            Section("Finder 常用格式") {
                ForEach(FileCategory.allCases, id: \.self) { category in
                    HStack {
                        Text(category.title).frame(width: 50, alignment: .leading)
                        ForEach(category.targets, id: \.self) { format in
                            Toggle(format.title, isOn: Binding(get: {
                                _ = model.settingsRevision
                                return model.preferences.enabledFormats(for: category).contains(format)
                            }, set: { enabled in
                                var formats = model.preferences.enabledFormats(for: category)
                                if enabled { formats.insert(format) } else { formats.remove(format) }
                                model.preferences.setEnabled(formats, for: category)
                                model.settingsRevision += 1
                            })).toggleStyle(.checkbox)
                        }
                    }
                }
                Text("變更會套用至下次開啟的 Finder 選單；批次檔案須為同一類別。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("轉檔引擎") {
                toolRow("FFmpeg", key: "ffmpeg", path: model.dependencies.ffmpeg,
                        detail: "音訊轉換與 WebP 輸出", command: "brew install ffmpeg")
                toolRow("LibreOffice", key: "libreOffice", path: model.dependencies.libreOffice,
                        detail: "Office 與 HTML → PDF", command: "brew install --cask libreoffice")
                if !model.dependencies.isBundled(model.dependencies.ffmpeg) {
                    toolRow("cwebp（選用）", key: "cwebp", path: model.dependencies.cwebp,
                        detail: "FFmpeg 無 libwebp 時使用", command: "brew install webp")
                }
                Text("PNG、JPEG、HEIC、TIFF 輸入與圖片／UTF-8 文字轉 PDF 使用 macOS 原生引擎。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("重新偵測") { Task { await model.refreshDependencies() } }
                    if !copied.isEmpty { Text(copied).font(.caption).foregroundStyle(.secondary) }
                }
                Text(model.dependencies.isSelfContained
                     ? "此版本已內附完整轉檔引擎，可離線使用，無須另外安裝工具。"
                     : "此開發版本尚未內附所有引擎。安裝指令只會複製到剪貼簿，請自行在終端機執行。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("系統整合") {
                Button("開啟 Finder 擴充功能設定", action: model.openExtensionSettings)
                Button("啟用系統通知", action: model.requestNotificationAuthorization)
                Text("首次使用請啟用 QuickConvert Finder。Finder 轉檔在背景執行、不開視窗；如需完成提示，請在此啟用系統通知。")
                    .font(.caption).foregroundStyle(.secondary)
                if !model.notificationStatus.isEmpty { Text(model.notificationStatus).font(.caption) }
            }
        }
        .formStyle(.grouped).frame(width: 680, height: 580)
    }

    private func toolRow(_ title: String, key: String, path: URL?, detail: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: path == nil ? "exclamationmark.circle" : "checkmark.circle.fill")
                    .foregroundStyle(path == nil ? .orange : .teal)
                Text(title).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if model.dependencies.isBundled(path) {
                    Text("已內附").font(.caption).foregroundStyle(.teal)
                } else {
                Button("選擇路徑…") { model.chooseTool(key) }
                Button("複製安裝指令") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    copied = "已複製 \(title) 安裝指令"
                }
                }
            }
            Text(path?.path ?? "尚未安裝").font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }
}
