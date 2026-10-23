import Foundation

public struct SegmentProgressUpdate: Sendable {
    public let segmentIndex: Int
    public let bytesRead: Int64
    public let currentByte: Int64
    public let isCompleted: Bool
}

public actor SegmentWorker {
    public let segmentIndex: Int
    public let url: URL
    public let startByte: Int64
    public let endByte: Int64
    public private(set) var currentByte: Int64
    public private(set) var isCompleted: Bool

    private let storage: FileStorageManager
    private var isCancelled = false

    public init(
        segmentIndex: Int,
        url: URL,
        startByte: Int64,
        endByte: Int64,
        currentByte: Int64? = nil,
        storage: FileStorageManager
    ) {
        self.segmentIndex = segmentIndex
        self.url = url
        self.startByte = startByte
        self.endByte = endByte
        self.currentByte = currentByte ?? startByte
        self.isCompleted = (currentByte ?? startByte) > endByte
        self.storage = storage
    }

    public func cancel() {
        isCancelled = true
    }

    public func run(onProgress: @Sendable @escaping (SegmentProgressUpdate) -> Void) async throws {
        guard currentByte <= endByte else {
            isCompleted = true
            onProgress(SegmentProgressUpdate(segmentIndex: segmentIndex, bytesRead: 0, currentByte: currentByte, isCompleted: true))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("bytes=\(currentByte)-\(endByte)", forHTTPHeaderField: "Range")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 60

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)

        let (asyncBytes, response) = try await session.bytes(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            // 206 Partial Content or 200 OK (if server ignored range)
            if httpResponse.statusCode != 206 && httpResponse.statusCode != 200 {
                throw NSError(domain: "SegmentWorker", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "HTTP Status \(httpResponse.statusCode) received for range."
                ])
            }
        }

        var buffer = Data()
        buffer.reserveCapacity(64 * 1024) // 64KB buffer

        for try await byte in asyncBytes {
            if isCancelled {
                break
            }

            buffer.append(byte)

            if buffer.count >= 64 * 1024 {
                let writeOffset = currentByte
                let bytesCount = Int64(buffer.count)
                try await storage.write(data: buffer, atOffset: writeOffset)
                currentByte += bytesCount
                buffer.removeAll(keepingCapacity: true)

                onProgress(SegmentProgressUpdate(
                    segmentIndex: segmentIndex,
                    bytesRead: bytesCount,
                    currentByte: currentByte,
                    isCompleted: currentByte > endByte
                ))
            }
        }

        // Flush remaining buffer
        if !buffer.isEmpty && !isCancelled {
            let writeOffset = currentByte
            let bytesCount = Int64(buffer.count)
            try await storage.write(data: buffer, atOffset: writeOffset)
            currentByte += bytesCount
            buffer.removeAll(keepingCapacity: false)

            onProgress(SegmentProgressUpdate(
                segmentIndex: segmentIndex,
                bytesRead: bytesCount,
                currentByte: currentByte,
                isCompleted: currentByte > endByte
            ))
        }

        if currentByte > endByte {
            isCompleted = true
        }

        session.finishTasksAndInvalidate()
    }
}
