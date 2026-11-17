import Foundation

public struct Dependencies: Sendable {
    public var ffmpeg: URL?
    public var libreOffice: URL?
    public var cwebp: URL?

    public init(ffmpeg: URL? = nil, libreOffice: URL? = nil, cwebp: URL? = nil) {
        self.ffmpeg = ffmpeg
        self.libreOffice = libreOffice
        self.cwebp = cwebp
    }

    public static func discover(environment: [String: String] = ProcessInfo.processInfo.environment) -> Dependencies {
        let paths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
            + (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        func find(_ names: [String]) -> URL? {
            names.map { URL(fileURLWithPath: $0) }.first {
                FileManager.default.isExecutableFile(atPath: $0.path)
            }
        }
        return Dependencies(
            ffmpeg: find(paths.map { "\($0)/ffmpeg" }),
            libreOffice: find(["/Applications/LibreOffice.app/Contents/MacOS/soffice",
                               NSHomeDirectory() + "/Applications/LibreOffice.app/Contents/MacOS/soffice"]
                              + paths.map { "\($0)/soffice" }),
            cwebp: find(paths.map { "\($0)/cwebp" })
        )
    }
}
