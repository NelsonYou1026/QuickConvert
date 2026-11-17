import Foundation

public enum DependencyPolicy: Sendable {
    case bundledOnly, bundledThenSystem
}

public struct Dependencies: Sendable {
    public var ffmpeg: URL?
    public var libreOffice: URL?
    public var cwebp: URL?
    private var bundleURL: URL?

    public init(ffmpeg: URL? = nil, libreOffice: URL? = nil, cwebp: URL? = nil) {
        self.ffmpeg = ffmpeg
        self.libreOffice = libreOffice
        self.cwebp = cwebp
    }

    public static var applicationBundleURL: URL? {
        var candidate = Bundle.main.bundleURL
        for _ in 0..<8 {
            if candidate.pathExtension == "app",
               FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Contents/Info.plist").path) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent == candidate { break }
            candidate = parent
        }
        return nil
    }

    public func isBundled(_ executable: URL?) -> Bool {
        guard let executable, let bundleURL else { return false }
        return executable.resolvingSymlinksInPath().path.hasPrefix(bundleURL.resolvingSymlinksInPath().path + "/")
    }

    public var isSelfContained: Bool { isBundled(ffmpeg) && isBundled(libreOffice) }

    public static var processArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    public static func discover(environment: [String: String] = ProcessInfo.processInfo.environment,
                                bundleURL: URL? = Dependencies.applicationBundleURL,
                                architecture: String = Dependencies.processArchitecture,
                                policy: DependencyPolicy = .bundledThenSystem) -> Dependencies {
        func executable(_ url: URL) -> URL? {
            var directory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &directory),
                  !directory.boolValue, FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
            return url
        }
        func bundled(_ path: String) -> URL? {
            guard let root = bundleURL, let found = executable(root.appendingPathComponent(path)),
                  found.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else { return nil }
            return found
        }
        var result = Dependencies(
            ffmpeg: bundled("Contents/Helpers/ffmpeg"),
            libreOffice: bundled("Contents/Helpers/LibreOffice-\(architecture).app/Contents/MacOS/soffice"),
            cwebp: bundled("Contents/Helpers/cwebp")
        )
        result.bundleURL = bundleURL
        guard policy == .bundledThenSystem else { return result }
        let paths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
            + (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        func find(_ names: [String]) -> URL? {
            names.lazy.compactMap { executable(URL(fileURLWithPath: $0)) }.first
        }
        result.ffmpeg = result.ffmpeg ?? find(paths.map { "\($0)/ffmpeg" })
        result.libreOffice = result.libreOffice ?? find(["/Applications/LibreOffice.app/Contents/MacOS/soffice",
                               NSHomeDirectory() + "/Applications/LibreOffice.app/Contents/MacOS/soffice"]
                              + paths.map { "\($0)/soffice" })
        result.cwebp = result.cwebp ?? find(paths.map { "\($0)/cwebp" })
        // Prefer the bundled FFmpeg's pinned WebP encoder over arbitrary external cwebp builds.
        if result.isBundled(result.ffmpeg) && !result.isBundled(result.cwebp) { result.cwebp = nil }
        return result
    }
}
