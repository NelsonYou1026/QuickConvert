import Foundation
import ImageIO
import PDFKit

public struct ConversionEngine: Sendable {
    public let dependencies: Dependencies
    public let runner: ProcessRunner

    public init(dependencies: Dependencies = .discover(), runner: ProcessRunner = .init()) {
        self.dependencies = dependencies
        self.runner = runner
    }

    /// Synchronous worker API. Call on a background task, never on the Finder or UI thread.
    public func convert(_ source: URL, to target: OutputFormat,
                        cancelled: @Sendable () -> Bool = { false }) throws -> URL {
        guard FormatPolicy.targets(for: [source], enabled: Set(OutputFormat.allCases)).contains(target) else {
            throw ConversionError.unsupported
        }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ConversionError.invalidSelection
        }
        if cancelled() { throw ConversionError.cancelled }
        let fm = FileManager.default
        let workspace = source.deletingLastPathComponent().appendingPathComponent(".quickconvert-" + UUID().uuidString)
        try fm.createDirectory(at: workspace, withIntermediateDirectories: false,
                               attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: workspace) }
        let output = workspace.appendingPathComponent("output.\(target.rawValue)")
        switch FileCategory.classify(source)! {
        case .audio:
            guard let ffmpeg = dependencies.ffmpeg else { throw ConversionError.missingTool("FFmpeg") }
            let codec: [String]
            switch target {
            case .mp3: codec = ["-c:a", "libmp3lame", "-q:a", "2"]
            case .wav: codec = ["-c:a", "pcm_s16le"]
            case .m4a: codec = ["-c:a", "aac", "-b:a", "192k"]
            case .flac: codec = ["-c:a", "flac"]
            default: throw ConversionError.unsupported
            }
            try runner.run(ffmpeg, arguments: ["-nostdin", "-hide_banner", "-loglevel", "error", "-n",
                                               "-filter_threads", "1", "-threads", "2",
                                               "-protocol_whitelist", "file,pipe", "-i", source.path,
                                               "-map", "0:a:0", "-vn"] + codec + ["-threads", "2", output.path],
                           directory: workspace, cancelled: cancelled)
        case .image:
            if target == .webp {
                let normalized = workspace.appendingPathComponent("normalized.png")
                try NativeConverter.image(source, to: normalized, target: .png)
                if let cwebp = dependencies.cwebp {
                    try runner.run(cwebp, arguments: ["-quiet", "-q", "90", normalized.path, "-o", output.path],
                                   directory: workspace, cancelled: cancelled)
                } else if let ffmpeg = dependencies.ffmpeg {
                    try runner.run(ffmpeg, arguments: ["-nostdin", "-hide_banner", "-loglevel", "error", "-n",
                                                   "-filter_threads", "1", "-threads", "2",
                                                   "-protocol_whitelist", "file,pipe", "-i", normalized.path,
                                                   "-frames:v", "1", "-c:v", "libwebp", "-quality", "90", "-threads", "2", output.path],
                               directory: workspace, cancelled: cancelled)
                } else { throw ConversionError.missingTool("FFmpeg（含 libwebp）或 cwebp") }
            } else {
                try NativeConverter.image(source, to: output, target: target)
            }
        case .document:
            if ["txt", "md"].contains(source.pathExtension.lowercased()) {
                try NativeConverter.textPDF(source, to: output, cancelled: cancelled)
            } else {
                try officePDF(source, output: output, workspace: workspace, cancelled: cancelled)
            }
        }
        if cancelled() { throw ConversionError.cancelled }
        try validate(output, target: target)
        return try OutputPublisher.publish(staged: output, source: source, target: target)
    }

    private func officePDF(_ source: URL, output: URL, workspace: URL,
                           cancelled: @Sendable () -> Bool) throws {
        guard let office = dependencies.libreOffice else { throw ConversionError.missingTool("LibreOffice") }
        let profile = workspace.appendingPathComponent("profile")
        let user = profile.appendingPathComponent("user")
        try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
        // An isolated profile avoids dispatching to an existing (possibly network-enabled) GUI instance.
        let registry = """
        <?xml version="1.0" encoding="UTF-8"?>
        <oor:items xmlns:oor="http://openoffice.org/2001/registry">
        <item oor:path="/org.openoffice.Office.Common/Security/Scripting"><prop oor:name="MacroSecurityLevel" oor:op="fuse"><value>3</value></prop><prop oor:name="DisableMacrosExecution" oor:op="fuse"><value>true</value></prop></item>
        <item oor:path="/org.openoffice.Office.Common/Load"><prop oor:name="UpdateDocMode" oor:op="fuse"><value>0</value></prop></item>
        </oor:items>
        """
        try registry.write(to: user.appendingPathComponent("registrymodifications.xcu"), atomically: true, encoding: .utf8)
        try runner.run(office, arguments: ["-env:UserInstallation=\(profile.absoluteString)",
                                          "--headless", "--nologo", "--nodefault", "--nofirststartwizard",
                                          "--convert-to", "pdf", "--outdir", workspace.path, source.path],
                       directory: workspace, cancelled: cancelled)
        let generated = workspace.appendingPathComponent(source.deletingPathExtension().lastPathComponent + ".pdf")
        guard FileManager.default.fileExists(atPath: generated.path) else { throw ConversionError.invalidOutput }
        if generated != output { try FileManager.default.moveItem(at: generated, to: output) }
    }

    private func validate(_ output: URL, target: OutputFormat) throws {
        guard (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 > 0 }) == true else {
            throw ConversionError.invalidOutput
        }
        if target == .pdf {
            guard let pdf = PDFDocument(url: output), pdf.pageCount > 0 else { throw ConversionError.invalidOutput }
        } else if [.jpg, .png, .webp].contains(target) {
            guard let source = CGImageSourceCreateWithURL(output as CFURL, nil),
                  CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw ConversionError.invalidOutput }
        }
    }
}
