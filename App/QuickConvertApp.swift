import SwiftUI
import AppKit

@main
struct QuickConvertApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup("QuickConvert") {
            ContentView(model: model)
                .onOpenURL { url in model.receive(url) }
                .task { await model.refreshDependencies() }
        }
        .defaultSize(width: 760, height: 580)
        .commands { CommandGroup(replacing: .newItem) {} }
        Settings { PreferencesView(model: model) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppModel.shared.isRunning {
            AppModel.shared.status = "請先取消或等待目前的轉檔完成，再結束程式。"
            sender.activate(ignoringOtherApps: true)
            return .terminateCancel
        }
        return .terminateNow
    }
}
