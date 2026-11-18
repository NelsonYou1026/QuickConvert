import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
    private let preferences = Preferences()

    override init() {
        super.init()
        // Observe menu events only; no enumeration, badges, or subprocesses in Finder.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems,
              let urls = FIFinderSyncController.default().selectedItemURLs(),
              urls.count <= 500, let first = urls.first,
              let category = FileCategory.classify(first) else { return nil }
        let targets = FormatPolicy.targets(for: urls, enabled: preferences.enabledFormats(for: category))
        guard !targets.isEmpty else { return nil }
        let menu = NSMenu()
        let parent = NSMenuItem(title: "QuickConvert", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "QuickConvert")
        for target in targets {
            let item = NSMenuItem(title: "轉換為 \(target.title)", action: #selector(convert(_:)), keyEquivalent: "")
            item.target = self
            item.tag = target.finderMenuTag
            submenu.addItem(item)
        }
        parent.submenu = submenu
        menu.addItem(parent)
        return menu
    }

    @objc private func convert(_ sender: NSMenuItem) {
        guard let target = OutputFormat(finderMenuTag: sender.tag),
              let files = FIFinderSyncController.default().selectedItemURLs() else {
            NSLog("QuickConvert Finder action has no valid format or selection (tag=%ld)", sender.tag)
            return
        }
        let request: ConversionRequest
        do { request = try ConversionRequest(files: files, target: target) }
        catch {
            NSLog("QuickConvert Finder selection rejected: %@", error.localizedDescription)
            return
        }
        // Always launch this extension's containing app, rather than another installed/dev copy
        // that happens to own the global quickconvert: scheme association.
        let host = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard host.pathExtension == "app" else {
            NSLog("QuickConvert Finder cannot locate its containing app")
            return
        }
        NSLog("QuickConvert Finder submitting %ld file(s) to %@", files.count, target.title)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open([request.url], withApplicationAt: host, configuration: configuration) { _, error in
            if let error { NSLog("QuickConvert host launch failed: %@", error.localizedDescription) }
        }
    }
}
