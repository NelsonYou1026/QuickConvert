import Foundation
import Darwin

public enum OutputPublisher {
    /// Publish a complete staged file with an atomic, exclusive rename; never replace an existing path.
    /// Staging must be in the source directory's filesystem.
    public static func publish(staged: URL, source: URL, target: OutputFormat) throws -> URL {
        let folder = source.deletingLastPathComponent()
        let stem = source.deletingPathExtension().lastPathComponent
        for number in 0..<100_000 {
            let suffix = number == 0 ? "" : " (\(number))"
            let destination = folder.appendingPathComponent("\(stem)\(suffix).\(target.rawValue)")
            var result = staged.path.withCString { from in
                destination.path.withCString { to in Darwin.renamex_np(from, to, UInt32(RENAME_EXCL)) }
            }
            // Older filesystems may support hard links but not exclusive rename.
            if result != 0 && [EINVAL, ENOTSUP, ENOSYS].contains(errno) {
                result = staged.path.withCString { from in
                    destination.path.withCString { to in Darwin.link(from, to) }
                }
            }
            if result == 0 { return destination }
            let code = errno
            if code != EEXIST { throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO) }
        }
        throw CocoaError(.fileWriteFileExists)
    }
}
