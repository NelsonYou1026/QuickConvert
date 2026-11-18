import Foundation

public enum FileCategory: String, CaseIterable, Sendable {
    case document, audio, image

    public var title: String {
        switch self {
        case .document: return "文件"
        case .audio: return "音訊"
        case .image: return "圖片"
        }
    }

    public var targets: [OutputFormat] {
        switch self {
        case .document: return [.pdf]
        case .audio: return [.mp3, .wav, .m4a, .flac]
        case .image: return [.jpg, .png, .webp, .pdf]
        }
    }

    public static func classify(_ url: URL) -> FileCategory? {
        switch url.pathExtension.lowercased() {
        case "docx", "xlsx", "pptx", "md", "txt", "html", "htm": return .document
        case "mp3", "wav", "flac", "m4a", "aac", "ogg": return .audio
        case "png", "jpg", "jpeg", "webp", "heic", "tiff", "tif": return .image
        default: return nil
        }
    }
}

public enum OutputFormat: String, CaseIterable, Codable, Sendable {
    case pdf, mp3, wav, m4a, flac, jpg, png, webp
    public var title: String { rawValue.uppercased() }

    /// Finder reconstructs menu items across XPC. Integer tags survive; representedObject does not.
    public var finderMenuTag: Int { Self.allCases.firstIndex(of: self)! + 1 }

    public init?(finderMenuTag: Int) {
        guard finderMenuTag > 0 && finderMenuTag <= Self.allCases.count else { return nil }
        self = Self.allCases[finderMenuTag - 1]
    }
}

public enum FormatPolicy {
    /// Menu construction does no disk I/O or tool discovery.
    public static func targets(for urls: [URL], enabled: Set<OutputFormat>) -> [OutputFormat] {
        guard let first = urls.first, let category = FileCategory.classify(first),
              urls.allSatisfy({ $0.isFileURL && FileCategory.classify($0) == category }) else { return [] }
        return category.targets.filter { target in
            enabled.contains(target) && urls.allSatisfy { normalizedExtension($0) != target.rawValue }
        }
    }

    private static func normalizedExtension(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return ext == "jpeg" ? "jpg" : ext
    }
}

public enum ConversionError: LocalizedError {
    case invalidSelection, unsupported, missingTool(String), processFailed(String), timedOut
    case cancelled, invalidOutput, invalidRequest

    public var errorDescription: String? {
        switch self {
        case .invalidSelection: return "請選取同一類別的本機一般檔案。"
        case .unsupported: return "不支援此轉換組合，或輸入與輸出格式相同。"
        case .missingTool(let name): return "找不到 \(name)，請到設定查看安裝指引。"
        case .processFailed(let message): return "轉檔工具失敗：\(message)"
        case .timedOut: return "轉檔逾時，已停止外部工具。"
        case .cancelled: return "轉檔已取消。"
        case .invalidOutput: return "工具未產生有效輸出檔案。"
        case .invalidRequest: return "無效的 QuickConvert 轉檔請求。"
        }
    }
}
