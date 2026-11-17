import Foundation
import Darwin

public struct ProcessRunner: Sendable {
    public var timeout: TimeInterval = 600
    public init(timeout: TimeInterval = 600) { self.timeout = timeout }

    /// File-backed diagnostics avoid pipe-buffer deadlocks. Child processes inherit the network denial.
    public func run(_ executable: URL, arguments: [String], directory: URL,
                    cancelled: @Sendable () -> Bool = { false }) throws {
        if cancelled() { throw ConversionError.cancelled }
        let log = directory.appendingPathComponent(UUID().uuidString + ".log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: log)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: log) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        process.arguments = ["-p", "(version 1)(allow default)(deny network*)", executable.path] + arguments
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        var interruption: ConversionError?
        while process.isRunning {
            if cancelled() { interruption = .cancelled }
            else if Date() >= deadline { interruption = .timedOut }
            if interruption != nil {
                process.terminate()
                let grace = Date().addingTimeInterval(1)
                while process.isRunning && Date() < grace { Thread.sleep(forTimeInterval: 0.02) }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                break
            }
            Thread.sleep(forTimeInterval: 0.025)
        }
        process.waitUntilExit()
        if let interruption { throw interruption }
        guard process.terminationReason == .exit && process.terminationStatus == 0 else {
            let reader = try FileHandle(forReadingFrom: log)
            defer { try? reader.close() }
            let size = try reader.seekToEnd()
            try reader.seek(toOffset: size > 8192 ? size - 8192 : 0)
            let data = try reader.readToEnd() ?? Data()
            throw ConversionError.processFailed(String(decoding: data, as: UTF8.self))
        }
    }
}
