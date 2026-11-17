import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var showPreferences = false
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.teal)
                    .frame(width: 58, height: 58).background(.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text("QuickConvert").font(.largeTitle.bold())
                    Text("轉換格式，留在本機。").foregroundStyle(.secondary)
                }
                Spacer()
                Button { showPreferences = true } label: { Image(systemName: "slider.horizontal.3") }
                    .help("設定與依賴工具")
            }

            VStack(spacing: 12) {
                Image(systemName: model.files.isEmpty ? "doc.on.doc" : "checkmark.circle")
                    .font(.system(size: 32, weight: .light)).foregroundStyle(.teal)
                Text(model.files.isEmpty ? "將檔案拖到這裡" : "已選取 \(model.files.count) 個檔案")
                    .font(.title3.weight(.semibold))
                Text(model.files.isEmpty ? "圖片、音訊與文件 · 支援同類別批次轉檔" : model.files.prefix(3).map(\.lastPathComponent).joined(separator: "、"))
                    .foregroundStyle(.secondary).lineLimit(2)
                Button("選取檔案…", action: model.chooseFiles).disabled(model.isRunning)
            }
            .frame(maxWidth: .infinity).padding(25)
            .background(isTargeted ? Color.teal.opacity(0.12) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.teal.opacity(isTargeted ? 0.8 : 0.2), style: StrokeStyle(lineWidth: 1, dash: [6])))
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
                guard !model.isRunning else { return false }
                Task {
                    var urls: [URL] = []
                    for provider in providers {
                        let url: URL? = await withCheckedContinuation { continuation in
                            _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
                        }
                        if let url { urls.append(url) }
                    }
                    model.select(urls)
                }
                return true
            }

            HStack {
                Text("轉換為").foregroundStyle(.secondary)
                Picker("輸出格式", selection: $model.target) {
                    ForEach(model.targets, id: \.self) { Text($0.title).tag($0) }
                }.labelsHidden().frame(width: 130).disabled(model.isRunning || model.targets.isEmpty)
                Spacer()
                if model.isRunning {
                    Button("取消", action: model.cancel)
                } else {
                    Button("開始轉檔", action: model.start)
                        .buttonStyle(.borderedProminent).tint(.teal)
                        .disabled(model.targets.isEmpty || model.files.count > 500)
                }
            }
            if model.isRunning { ProgressView(value: Double(model.completed), total: Double(max(model.total, 1))) }
            Text(model.status).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            if !model.results.isEmpty {
                List(Array(model.results.enumerated()), id: \.offset) { _, result in
                    HStack {
                        Image(systemName: result.output == nil ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(result.output == nil ? .orange : .teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.output?.lastPathComponent ?? result.source.lastPathComponent)
                            if let error = result.error { Text(error).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                        }
                        Spacer()
                        if let url = result.output { Button("顯示", action: { model.reveal(url) }) }
                    }
                }.listStyle(.inset).frame(minHeight: 90)
            } else { Spacer(minLength: 0) }
            HStack(spacing: 5) {
                Image(systemName: "lock.shield")
                Text("全本機處理 · 自動保留原檔 · 輸出至原資料夾")
                Spacer()
                Button("啟用 Finder 選單", action: model.openExtensionSettings).buttonStyle(.link)
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).frame(minWidth: 640, minHeight: 540)
        .sheet(isPresented: $showPreferences) {
            VStack(alignment: .trailing, spacing: 0) {
                PreferencesView(model: model)
                Button("完成") { showPreferences = false }.keyboardShortcut(.defaultAction).padding()
            }
        }
    }
}
