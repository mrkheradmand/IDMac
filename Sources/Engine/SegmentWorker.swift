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
    public let etag: String?
    public let lastModified: String?

    private let storage: FileStorageManager
    private var isCancelled = false

    public init(
        segmentIndex: Int,
        url: URL,
        startByte: Int64,
        endByte: Int64,
        currentByte: Int64? = nil,
        storage: FileStorageManager,
        etag: String? = nil,
        lastModified: String? = nil
    ) {
        self.segmentIndex = segmentIndex
        self.url = url
        self.startByte = startByte
        self.endByte = endByte
        let initialCurrent = currentByte ?? startByte
        self.currentByte = initialCurrent
        self.isCompleted = (endByte > 0) ? (initialCurrent > endByte) : false
        self.storage = storage
        self.etag = etag
        self.lastModified = lastModified
    }

    public func cancel() {
        isCancelled = true
    }

    public func run(onProgress: @Sendable @escaping (SegmentProgressUpdate) -> Void) async throws {
        if endByte > 0 && currentByte > endByte {
            isCompleted = true
            onProgress(SegmentProgressUpdate(segmentIndex: segmentIndex, bytesRead: 0, currentByte: currentByte, isCompleted: true))
            return
        }

        var request = URLRequest(url: url)
        if endByte > 0 {
            request.setValue("bytes=\(currentByte)-\(endByte)", forHTTPHeaderField: "Range")
        } else if currentByte > 0 {
            request.setValue("bytes=\(currentByte)-", forHTTPHeaderField: "Range")
        }

        // Server Drift Detection: inject If-Range with ETag or Last-Modified if resuming or requesting sub-range
        if currentByte > 0 {
            if let etag = etag, !etag.isEmpty {
                request.setValue(etag, forHTTPHeaderField: "If-Range")
            } else if let lastModified = lastModified, !lastModified.isEmpty {
                request.setValue(lastModified, forHTTPHeaderField: "If-Range")
            }
        }

        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 60

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)

        let (asyncBytes, response) = try await session.bytes(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            // Strict HTTP Range Enforcement:
            // If requesting a sub-range (currentByte > 0), the server MUST return 206 Partial Content.
            // Returning 200 OK means the server returned the entire file from byte 0 (either ignored Range
            // or If-Range detected server drift). Writing byte 0 at offset currentByte corrupts the payload.
            if httpResponse.statusCode == 200 && currentByte > 0 {
                session.finishTasksAndInvalidate()
                throw NSError(domain: "SegmentWorker", code: 200, userInfo: [
                    NSLocalizedDescriptionKey: "Server returned 200 OK instead of 206 Partial Content for byte offset \(currentByte). Remote file may have been updated or server does not support ranges."
                ])
            }

            if httpResponse.statusCode != 206 && httpResponse.statusCode != 200 {
                session.finishTasksAndInvalidate()
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

            let bytesCount = Int64(buffer.count)
            // Flush buffer when 64KB reached or when all needed segment bytes are collected
            if bytesCount >= 64 * 1024 || (endByte > 0 && bytesCount >= (endByte - currentByte + 1)) {
                let toWrite: Data
                if endByte > 0 && bytesCount > (endByte - currentByte + 1) {
                    let needed = max(0, Int(endByte - currentByte + 1))
                    toWrite = buffer.prefix(needed)
                    buffer.removeAll(keepingCapacity: false)
                } else {
                    toWrite = buffer
                    buffer.removeAll(keepingCapacity: true)
                }

                if !toWrite.isEmpty {
                    let writeOffset = currentByte
                    let writtenCount = Int64(toWrite.count)
                    try await storage.write(data: toWrite, atOffset: writeOffset)
                    currentByte += writtenCount

                    onProgress(SegmentProgressUpdate(
                        segmentIndex: segmentIndex,
                        bytesRead: writtenCount,
                        currentByte: currentByte,
                        isCompleted: endByte > 0 ? (currentByte > endByte) : false
                    ))
                }

                if endByte > 0 && currentByte > endByte {
                    break
                }
            }
        }

        // Flush remaining buffer
        if !buffer.isEmpty && !isCancelled {
            let toWrite: Data
            if endByte > 0 && Int64(buffer.count) > (endByte - currentByte + 1) {
                let needed = max(0, Int(endByte - currentByte + 1))
                toWrite = buffer.prefix(needed)
            } else {
                toWrite = buffer
            }

            if !toWrite.isEmpty {
                let writeOffset = currentByte
                let writtenCount = Int64(toWrite.count)
                try await storage.write(data: toWrite, atOffset: writeOffset)
                currentByte += writtenCount

                onProgress(SegmentProgressUpdate(
                    segmentIndex: segmentIndex,
                    bytesRead: writtenCount,
                    currentByte: currentByte,
                    isCompleted: endByte > 0 ? (currentByte > endByte) : false
                ))
            }
            buffer.removeAll(keepingCapacity: false)
        }

        if endByte > 0 {
            isCompleted = (currentByte > endByte)
        } else {
            isCompleted = true
        }

        session.finishTasksAndInvalidate()
    }
}
