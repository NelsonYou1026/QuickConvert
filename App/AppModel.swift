import SwiftUI
import AppKit
import UserNotifications
import FinderSync

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    @Published var files: [URL] = []
    @Published var target: OutputFormat = .pdf
    @Published var dependencies = Dependencies()
    @Published var isRunning = false
    @Published var completed = 0
    @Published var total = 0
    @Published var results: [FileConversionResult] = []
    @Published var status = "選取檔案，或直接從 Finder 右鍵開始。"
    @Published var notificationStatus = ""
    @Published var settingsRevision = 0
    private var pending: [ConversionRequest] = []
    private var task: Task<Void, Never>?
    private var notificationAuthorization: Task<Bool, Never>?
    let preferences = Preferences()

    var targets: [OutputFormat] {
        FormatPolicy.targets(for: files, enabled: Set(OutputFormat.allCases))
    }

    func refreshDependencies() async {
        let found = await Task.detached { Dependencies.discover() }.value
        var resolved = found
        for key in ["ffmpeg", "libreOffice", "cwebp"] {
            let current = key == "ffmpeg" ? found.ffmpeg : (key == "libreOffice" ? found.libreOffice : found.cwebp)
            if found.isBundled(current) || (key == "cwebp" && found.isBundled(found.ffmpeg)) { continue }
            if let path = UserDefaults.standard.string(forKey: "tool.\(key)"),
               FileManager.default.isExecutableFile(atPath: path) {
                if key == "ffmpeg" { resolved.ffmpeg = URL(fileURLWithPath: path) }
                else if key == "libreOffice" { resolved.libreOffice = URL(fileURLWithPath: path) }
                else { resolved.cwebp = URL(fileURLWithPath: path) }
            }
        }
        dependencies = resolved
    }

    func chooseTool(_ key: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.message = "選取 \(key == "libreOffice" ? "soffice" : key) 執行檔"
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url,
           FileManager.default.isExecutableFile(atPath: url.path) {
            UserDefaults.standard.set(url.path, forKey: "tool.\(key)")
            Task { await refreshDependencies() }
        }
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "選取同一類別的圖片、音訊或文件（最多 500 個）"
        if panel.runModal() == .OK { select(panel.urls) }
    }

    func select(_ urls: [URL]) {
        guard !isRunning else { return }
        files = urls
        if !targets.contains(target), let first = targets.first { target = first }
        status = targets.isEmpty ? "請選取同一類別、支援的檔案（最多 500 個）。" : "已選取 \(urls.count) 個檔案；輸出會儲存在原資料夾。"
    }

    func receive(_ url: URL) {
        do {
            let request = try ConversionRequest(url: url)
            NSLog("QuickConvert received %ld file(s) for %@", request.files.count, request.target.title)
            enqueue(request)
        } catch {
            status = error.localizedDescription
            NSLog("QuickConvert rejected conversion request: %@", error.localizedDescription)
        }
    }

    func start() {
        do { enqueue(try ConversionRequest(files: files, target: target)) }
        catch { status = error.localizedDescription }
    }

    func enqueue(_ request: ConversionRequest) {
        pending.append(request)
        if !isRunning { runNext() }
    }

    func cancel() {
        pending.removeAll()
        task?.cancel()
        status = "正在取消…"
    }

    private func runNext() {
        guard !pending.isEmpty else { isRunning = false; task = nil; return }
        let request = pending.removeFirst()
        isRunning = true
        completed = 0
        total = request.files.count
        results = []
        files = request.files
        target = request.target
        status = "正在轉換為 \(request.target.title)…"
        task = Task {
            // Tool discovery happens in the host, never inside Finder's menu callback.
            status = "正在偵測轉檔工具…"
            await refreshDependencies()
            status = "正在準備轉檔…"
            notify("開始轉檔", body: "\(request.files.count) 個檔案 → \(request.target.title)")
            status = "正在轉換為 \(request.target.title)…"
            let engine = ConversionEngine(dependencies: dependencies)
            let output = await BatchConverter.run(request, engine: engine) { progress in
                await self.update(progress)
            }
            let wasCancelled = Task.isCancelled
            let successes = output.filter { $0.output != nil }.count
            let failures = output.filter { $0.error != nil }.count
            status = wasCancelled ? "已取消；已完成 \(successes) 個檔案。" : "完成 \(successes) 個，失敗 \(failures) 個。"
            notify(wasCancelled ? "轉檔已取消" : (failures == 0 ? "轉檔完成" : "部分轉檔失敗"), body: status)
            runNext()
        }
    }

    private func update(_ progress: BatchProgress) {
        completed = progress.completed
        results.append(progress.result)
        status = "\(progress.completed) / \(progress.total) · \(progress.result.source.lastPathComponent)"
    }

    private func notify(_ title: String, body: String) {
        // Permission dialogs or an unavailable notification service must never block a conversion.
        if notificationAuthorization == nil {
            notificationAuthorization = Task {
                let center = UNUserNotificationCenter.current()
                let settings = await center.notificationSettings()
                if settings.authorizationStatus == .notDetermined {
                    return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
                }
                return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
        let authorization = notificationAuthorization!
        Task {
            guard await authorization.value else {
                notificationStatus = "系統通知未啟用；可在此視窗查看轉檔結果。"
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            do {
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
            } catch {
                notificationStatus = "系統通知未啟用；可在此視窗查看轉檔結果。"
            }
        }
    }

    func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    func openExtensionSettings() { FIFinderSyncController.showExtensionManagementInterface() }
}
