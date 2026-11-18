import SwiftUI
import AppKit

@main
enum QuickConvertApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var receivedRequest = false
    private var idleExit: Task<Void, Never>?

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppModel.shared.activityDidChange = { [weak self] in self?.updateLifetime() }
        // SwiftUI presentations may replace a hosting window's delegate. Observe closure directly.
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification, object: nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement prevents a Dock flash. URL launches never construct a SwiftUI window.
        if !receivedRequest, notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true {
            showMainWindow()
        }
        updateLifetime()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        showMainWindow()
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedRequest = true
        idleExit?.cancel()
        for url in urls { AppModel.shared.receive(url) }
        updateLifetime()
    }

    @objc private func showMainWindow() {
        if mainWindow == nil {
            mainWindow = makeWindow(title: "QuickConvert", width: 760, height: 580,
                content: ContentView(model: .shared).task { await AppModel.shared.refreshDependencies() })
        }
        present(mainWindow!)
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(title: "QuickConvert 設定", width: 680, height: 580,
                content: PreferencesView(model: .shared).task { await AppModel.shared.refreshDependencies() })
        }
        present(settingsWindow!)
    }

    private func makeWindow<Content: View>(title: String, width: CGFloat, height: CGFloat, content: Content) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: width, height: height))
        window.center()
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        return window
    }

    private func present(_ window: NSWindow) {
        idleExit?.cancel()
        NSApp.setActivationPolicy(.regular)
        if NSApp.mainMenu == nil { installMenu() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func installMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "QuickConvert")
        appMenu.addItem(withTitle: "關於 QuickConvert", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settings = appMenu.addItem(withTitle: "設定…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隱藏 QuickConvert", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "結束 QuickConvert", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "編輯")
        editMenu.addItem(withTitle: "剪下", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷貝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "貼上", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全選", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "視窗")
        windowMenu.addItem(withTitle: "關閉", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "縮到最小", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = menu
    }

    @objc private func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === mainWindow { mainWindow = nil }
        if notification.object as? NSWindow === settingsWindow { settingsWindow = nil }
        if mainWindow == nil && settingsWindow == nil { NSApp.setActivationPolicy(.accessory) }
        updateLifetime()
    }

    private func updateLifetime() {
        idleExit?.cancel()
        guard mainWindow == nil, settingsWindow == nil, !AppModel.shared.isRunning else { return }
        // A single grace period lets notifications submit and coalesces arriving Finder jobs.
        // There is no resident worker, periodic idle timer, or launch-at-login service.
        idleExit = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, self.mainWindow == nil, self.settingsWindow == nil,
                  !AppModel.shared.isRunning else { return }
            NSLog("QuickConvert background queue idle; exiting")
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppModel.shared.isRunning {
            AppModel.shared.status = "請先取消或等待目前的轉檔完成，再結束程式。"
            return .terminateCancel
        }
        return .terminateNow
    }
}
