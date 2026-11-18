import SwiftUI
import AppKit

@main
struct QuickConvertApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup("QuickConvert") {
            ContentView(model: model)
                .task { await model.refreshDependencies() }
        }
        .defaultSize(width: 760, height: 580)
        .commands { CommandGroup(replacing: .newItem) {} }
        Settings { PreferencesView(model: model) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Process-level handling also receives Finder jobs on cold launch or with all windows closed.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { AppModel.shared.receive(url) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppModel.shared.isRunning {
            AppModel.shared.status = "請先取消或等待目前的轉檔完成，再結束程式。"
            sender.activate(ignoringOtherApps: true)
            return .terminateCancel
        }
        return .terminateNow
    }
}
