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
            // Snapshot selection while Finder guarantees selectedItemURLs is valid.
            item.representedObject = try? ConversionRequest(files: urls, target: target).url
            submenu.addItem(item)
        }
        parent.submenu = submenu
        menu.addItem(parent)
        return menu
    }

    @objc private func convert(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration) { _, error in
            if let error { NSLog("QuickConvert host launch failed: %@", error.localizedDescription) }
        }
    }
}
