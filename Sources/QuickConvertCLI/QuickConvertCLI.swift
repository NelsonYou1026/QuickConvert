import Foundation
import QuickConvertCore

@main
struct QuickConvertCLI {
    static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        let bundledOnly = arguments.first == "--bundled-only"
        if bundledOnly { arguments.removeFirst() }
        let tools = Dependencies.discover(policy: bundledOnly ? .bundledOnly : .bundledThenSystem)
        if arguments == ["--check"] {
            print("FFmpeg: \(tools.ffmpeg?.path ?? "未安裝")")
            print("LibreOffice: \(tools.libreOffice?.path ?? "未安裝")")
            print("cwebp（選用）: \(tools.cwebp?.path ?? "未安裝")")
            print("Self-contained: \(tools.isSelfContained ? "yes" : "no")")
            if bundledOnly && !tools.isSelfContained { exit(1) }
            return
        }
        guard arguments.count >= 3, arguments[0] == "--to",
              let target = OutputFormat(rawValue: arguments[1].lowercased()) else {
            print("Usage: quickconvert [--bundled-only] --to <pdf|mp3|wav|m4a|flac|jpg|png|webp> <file> [file ...]\n       quickconvert [--bundled-only] --check")
            exit(arguments.isEmpty || arguments == ["--help"] ? 0 : 2)
        }
        do {
            let files = arguments.dropFirst(2).map { URL(fileURLWithPath: $0).standardizedFileURL }
            let request = try ConversionRequest(files: files, target: target)
            let results = await BatchConverter.run(request, engine: ConversionEngine(dependencies: tools)) { progress in
                if let output = progress.result.output { print(output.path) }
                else { FileHandle.standardError.write(Data("\(progress.result.source.lastPathComponent): \(progress.result.error ?? "失敗")\n".utf8)) }
            }
            if results.contains(where: { $0.error != nil }) { exit(1) }
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(2)
        }
    }
}
