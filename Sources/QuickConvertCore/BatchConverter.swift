import Foundation

public struct FileConversionResult: Sendable {
    public let source: URL
    public let output: URL?
    public let error: String?
}

public struct BatchProgress: Sendable {
    public let completed: Int
    public let total: Int
    public let result: FileConversionResult
}

public enum BatchConverter {
    /// Sequential files bound CPU/memory use; failures are isolated per file.
    public static func run(_ request: ConversionRequest, engine: ConversionEngine = .init(),
                           progress: @escaping @Sendable (BatchProgress) async -> Void = { _ in }) async -> [FileConversionResult] {
        var results: [FileConversionResult] = []
        for source in request.files {
            if Task.isCancelled { break }
            let worker = Task.detached(priority: .utility) {
                do {
                    let output = try autoreleasepool {
                        try engine.convert(source, to: request.target, cancelled: { Task.isCancelled })
                    }
                    return FileConversionResult(source: source, output: output, error: nil)
                } catch {
                    return FileConversionResult(source: source, output: nil, error: error.localizedDescription)
                }
            }
            let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            results.append(result)
            await progress(BatchProgress(completed: results.count, total: request.files.count, result: result))
        }
        return results
    }
}
