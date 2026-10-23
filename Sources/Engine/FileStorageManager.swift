import Foundation

public actor FileStorageManager {
    private let destinationURL: URL
    private var fileHandle: FileHandle?

    public init(destinationURL: URL) {
        self.destinationURL = destinationURL
    }

    public func prepareFile(totalSize: Int64) throws {
        let fileManager = FileManager.default
        let folder = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        if !fileManager.fileExists(atPath: destinationURL.path) {
            fileManager.createFile(atPath: destinationURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: destinationURL)
        if totalSize > 0 {
            try handle.truncate(atOffset: UInt64(totalSize))
        }
        self.fileHandle = handle
    }

    public func write(data: Data, atOffset offset: Int64) throws {
        guard let handle = fileHandle else {
            let handle = try FileHandle(forWritingTo: destinationURL)
            self.fileHandle = handle
            try handle.seek(toOffset: UInt64(offset))
            try handle.write(contentsOf: data)
            return
        }
        try handle.seek(toOffset: UInt64(offset))
        try handle.write(contentsOf: data)
    }

    public func close() {
        try? fileHandle?.synchronize()
        try? fileHandle?.close()
        fileHandle = nil
    }

    deinit {
        try? fileHandle?.close()
    }
}
