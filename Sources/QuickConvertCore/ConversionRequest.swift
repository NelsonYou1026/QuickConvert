import Foundation

public struct ConversionRequest: Sendable {
    public let files: [URL]
    public let target: OutputFormat

    public init(files: [URL], target: OutputFormat) throws {
        guard !files.isEmpty, files.count <= 500,
              FormatPolicy.targets(for: files, enabled: Set(OutputFormat.allCases)).contains(target) else {
            throw ConversionError.invalidSelection
        }
        self.files = files
        self.target = target
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = "quickconvert"
        components.host = "convert"
        components.queryItems = [URLQueryItem(name: "to", value: target.rawValue)]
            + files.map { URLQueryItem(name: "file", value: $0.path) }
        return components.url!
    }

    public init(url: URL) throws {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme == "quickconvert", c.host == "convert", c.user == nil, c.password == nil,
              c.port == nil, c.fragment == nil, c.path.isEmpty,
              let items = c.queryItems, items.allSatisfy({ ["to", "file"].contains($0.name) }),
              items.filter({ $0.name == "to" }).count == 1,
              let name = items.first(where: { $0.name == "to" })?.value,
              let format = OutputFormat(rawValue: name) else { throw ConversionError.invalidRequest }
        let paths = items.filter { $0.name == "file" }.compactMap(\.value)
        guard paths.count == items.count - 1,
              paths.allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0") }) else {
            throw ConversionError.invalidRequest
        }
        try self.init(files: paths.map { URL(fileURLWithPath: $0) }, target: format)
    }
}
