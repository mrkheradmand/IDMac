import Foundation

public struct ProbeResult: Sendable {
    public let filename: String
    public let totalSize: Int64
    public let supportsResume: Bool
    public let contentType: String?
    public let etag: String?
    public let lastModified: String?
}

public actor DownloadEngine {
    public let id: UUID
    public let url: URL
    public let destinationURL: URL
    public let connectionCount: Int
    public let etag: String?
    public let lastModified: String?

    private var workers: [SegmentWorker] = []
    private var storage: FileStorageManager?
    private var isRunning = false
    private var isCancelled = false

    public init(
        id: UUID,
        url: URL,
        destinationURL: URL,
        connectionCount: Int = 8,
        etag: String? = nil,
        lastModified: String? = nil
    ) {
        self.id = id
        self.url = url
        self.destinationURL = destinationURL
        self.connectionCount = connectionCount
        self.etag = etag
        self.lastModified = lastModified
    }

    public static func probe(url: URL) async throws -> ProbeResult {
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        headRequest.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: headRequest)
        _ = data

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "DownloadEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }

        var totalSize: Int64 = httpResponse.expectedContentLength
        if totalSize <= 0, let clHeader = httpResponse.value(forHTTPHeaderField: "Content-Length"), let parsed = Int64(clHeader) {
            totalSize = parsed
        }

        let acceptRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased()
        let supportsResume = acceptRanges?.contains("bytes") ?? (httpResponse.statusCode == 206 || totalSize > 0)

        var filename = url.lastPathComponent
        if let disposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition") {
            if let extracted = parseFilename(fromContentDisposition: disposition) {
                filename = extracted
            }
        }
        if filename.isEmpty || filename == "/" {
            filename = "download_\(Int(Date().timeIntervalSince1970))"
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
        let etag = httpResponse.value(forHTTPHeaderField: "ETag")
        let lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")

        return ProbeResult(
            filename: filename,
            totalSize: max(0, totalSize),
            supportsResume: supportsResume,
            contentType: contentType,
            etag: etag,
            lastModified: lastModified
        )
    }

    private static func parseFilename(fromContentDisposition header: String) -> String? {
        let pattern = "filename[*]?=['\"]?([^'\";]+)['\"]?"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = header as NSString
            let results = regex.matches(in: header, options: [], range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges > 1 {
                return nsString.substring(with: match.range(at: 1))
            }
        }
        return nil
    }

    public func pause() async {
        isCancelled = true
        for worker in workers {
            await worker.cancel()
        }
        workers.removeAll()
        await storage?.close()
        isRunning = false
    }

    public func start(
        existingSegments: [(index: Int, start: Int64, end: Int64, current: Int64, isCompleted: Bool)],
        totalSize: Int64,
        supportsResume: Bool,
        onProgress: @Sendable @escaping (SegmentProgressUpdate) -> Void,
        onComplete: @Sendable @escaping () -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        isCancelled = false
        isRunning = true

        let fileStorage = FileStorageManager(destinationURL: destinationURL)
        self.storage = fileStorage

        do {
            try await fileStorage.prepareFile(totalSize: totalSize)

            let segmentsToUse: [(index: Int, start: Int64, end: Int64, current: Int64, isCompleted: Bool)]
            if existingSegments.isEmpty {
                segmentsToUse = calculateSegments(totalSize: totalSize, count: (supportsResume && totalSize > 0) ? connectionCount : 1)
            } else {
                segmentsToUse = existingSegments
            }

            var activeWorkers: [SegmentWorker] = []
            for seg in segmentsToUse {
                let worker = SegmentWorker(
                    segmentIndex: seg.index,
                    url: url,
                    startByte: seg.start,
                    endByte: seg.end,
                    currentByte: seg.current,
                    storage: fileStorage,
                    etag: etag,
                    lastModified: lastModified
                )
                activeWorkers.append(worker)
            }
            self.workers = activeWorkers

            try await withThrowingTaskGroup(of: Void.self) { group in
                for worker in activeWorkers {
                    group.addTask {
                        try await worker.run(onProgress: onProgress)
                    }
                }
                try await group.waitForAll()
            }

            await fileStorage.close()
            isRunning = false
            if !isCancelled {
                onComplete()
            }
        } catch {
            await fileStorage.close()
            isRunning = false
            if !isCancelled && !Task.isCancelled && !isCancellationError(error) {
                onError(error)
            }
        }
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return true }
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError { return true }
        if error.localizedDescription.lowercased().contains("cancel") { return true }
        return false
    }

    private func calculateSegments(totalSize: Int64, count: Int) -> [(index: Int, start: Int64, end: Int64, current: Int64, isCompleted: Bool)] {
        let effectiveCount = (totalSize > 0) ? max(1, min(count, Int(totalSize))) : 1
        guard effectiveCount > 1, totalSize > 0 else {
            return [(index: 0, start: 0, end: max(0, totalSize - 1), current: 0, isCompleted: false)]
        }

        var results: [(index: Int, start: Int64, end: Int64, current: Int64, isCompleted: Bool)] = []
        let chunkSize = totalSize / Int64(effectiveCount)

        for i in 0..<effectiveCount {
            let start = Int64(i) * chunkSize
            let end = (i == effectiveCount - 1) ? (totalSize - 1) : (start + chunkSize - 1)
            results.append((index: i, start: start, end: end, current: start, isCompleted: false))
        }

        return results
    }
}
