import Foundation
import CoreText

/// The headless Office backend uses Fontconfig, which does not discover macOS asset fonts itself.
/// Bridge locally available CoreText fonts without copying, downloading, or changing document fonts.
enum OfficeFontConfiguration {
    static func prepare(in workspace: URL) throws -> [String: String] {
        let manager = FileManager.default
        let available = CTFontManagerCopyAvailableFontURLs() as? [URL] ?? []
        var directories = Set(available.filter { $0.isFileURL && manager.fileExists(atPath: $0.path) }
            .map { $0.deletingLastPathComponent().path })
        for path in ["/System/Library/Fonts", "/Library/Fonts", NSHomeDirectory() + "/Library/Fonts"] {
            var isDirectory: ObjCBool = false
            if manager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                directories.insert(path)
            }
        }
        // Only metadata is cached. No font files or document content are copied here.
        let cache = try cacheDirectory(in: workspace)
        let paths = directories.sorted().map { "  <dir>\(escape($0))</dir>" }.joined(separator: "\n")
        let config = """
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
        \(paths)
          <cachedir>\(escape(cache.path))</cachedir>
        </fontconfig>
        """
        let file = workspace.appendingPathComponent("fonts.conf")
        try config.write(to: file, atomically: true, encoding: .utf8)
        return ["FONTCONFIG_FILE": file.path]
    }

    private static func cacheDirectory(in workspace: URL) throws -> URL {
        let manager = FileManager.default
        if let root = try? manager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let persistent = root.appendingPathComponent("QuickConvert/Fontconfig", isDirectory: true)
            if (try? manager.createDirectory(at: persistent, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])) != nil,
               manager.isWritableFile(atPath: persistent.path) { return persistent }
        }
        let temporary = workspace.appendingPathComponent("font-cache", isDirectory: true)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return temporary
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
