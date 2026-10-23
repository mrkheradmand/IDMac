import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
public final class DownloadCoordinator {
    public static let shared = DownloadCoordinator()

    public var activeEngines: [UUID: DownloadEngine] = [:]
    public var activeTasks: [UUID: Task<Void, Never>] = [:]
    private var speedSamplers: [UUID: (bytes: Int64, timestamp: Date)] = [:]

    public var selectedDownload: DownloadItem?
    public var isAddingDownloadSheetPresented = false

    public var modelContext: ModelContext?

    public init() {}

    public func addDownload(
        urlString: String,
        destinationFolder: URL,
        connectionCount: Int = 8,
        modelContext: ModelContext,
        startImmediately: Bool = true
    ) async {
        self.modelContext = modelContext
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        var detectedFilename = url.lastPathComponent
        if detectedFilename.isEmpty {
            detectedFilename = "download_\(Int(Date().timeIntervalSince1970))"
        }
        var totalSize: Int64 = 0
        var supportsResume = false

        do {
            let probe = try await DownloadEngine.probe(url: url)
            detectedFilename = probe.filename
            totalSize = probe.totalSize
            supportsResume = probe.supportsResume
        } catch {
            print("Probe error: \(error.localizedDescription), proceeding with defaults")
        }

        let destinationURL = destinationFolder.appendingPathComponent(detectedFilename)
        let category = DownloadCategory.inferCategory(fromFilename: detectedFilename)

        let item = DownloadItem(
            urlString: urlString,
            filename: detectedFilename,
            fileSize: totalSize,
            downloadedBytes: 0,
            status: .queued,
            category: category,
            dateAdded: Date(),
            destinationPath: destinationURL.path,
            connectionCount: connectionCount,
            supportsResume: supportsResume
        )

        modelContext.insert(item)
        try? modelContext.save()

        if startImmediately {
            start(item: item, modelContext: modelContext)
        }
    }

    public func start(item: DownloadItem, modelContext: ModelContext) {
        self.modelContext = modelContext
        let itemId = item.id
        guard activeEngines[itemId] == nil, let url = URL(string: item.urlString) else { return }

        let destURL = URL(fileURLWithPath: item.destinationPath)
        let engine = DownloadEngine(
            id: itemId,
            url: url,
            destinationURL: destURL,
            connectionCount: item.connectionCount
        )
        activeEngines[itemId] = engine

        item.status = .downloading
        item.errorMessage = nil
        try? modelContext.save()

        speedSamplers[itemId] = (bytes: item.downloadedBytes, timestamp: Date())

        let task = Task {
            let existingSegments = item.segments.sorted(by: { $0.segmentIndex < $1.segmentIndex }).map {
                (index: $0.segmentIndex, start: $0.startByte, end: $0.endByte, current: $0.currentByte, isCompleted: $0.isCompleted)
            }

            await engine.start(
                existingSegments: existingSegments,
                totalSize: item.fileSize,
                supportsResume: item.supportsResume,
                onProgress: { update in
                    Task { @MainActor in
                        DownloadCoordinator.shared.handleProgress(update: update, for: itemId)
                    }
                },
                onComplete: {
                    Task { @MainActor in
                        DownloadCoordinator.shared.handleComplete(for: itemId)
                    }
                },
                onError: { error in
                    Task { @MainActor in
                        DownloadCoordinator.shared.handleError(error, for: itemId)
                    }
                }
            )
        }
        activeTasks[itemId] = task
    }

    public func pause(item: DownloadItem, modelContext: ModelContext) {
        self.modelContext = modelContext
        let itemId = item.id
        if let engine = activeEngines[itemId] {
            Task {
                await engine.pause()
            }
        }
        activeTasks[itemId]?.cancel()
        activeTasks.removeValue(forKey: itemId)
        activeEngines.removeValue(forKey: itemId)
        speedSamplers.removeValue(forKey: itemId)

        item.status = .paused
        item.currentSpeed = 0
        try? modelContext.save()
    }

    public func resume(item: DownloadItem, modelContext: ModelContext) {
        start(item: item, modelContext: modelContext)
    }

    public func delete(item: DownloadItem, deleteFile: Bool, modelContext: ModelContext) {
        pause(item: item, modelContext: modelContext)
        if deleteFile {
            let path = item.destinationPath
            try? FileManager.default.removeItem(atPath: path)
        }
        modelContext.delete(item)
        try? modelContext.save()
        if selectedDownload?.id == item.id {
            selectedDownload = nil
        }
    }

    public func pauseAll(items: [DownloadItem], modelContext: ModelContext) {
        for item in items where item.status == .downloading {
            pause(item: item, modelContext: modelContext)
        }
    }

    public func resumeAll(items: [DownloadItem], modelContext: ModelContext) {
        for item in items where item.status == .paused || item.status == .queued {
            start(item: item, modelContext: modelContext)
        }
    }

    public func pauseAllDownloads() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<DownloadItem>()
        if let items = try? context.fetch(descriptor) {
            pauseAll(items: items, modelContext: context)
        }
    }

    public func resumeAllDownloads() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<DownloadItem>()
        if let items = try? context.fetch(descriptor) {
            resumeAll(items: items, modelContext: context)
        }
    }

    public func getActiveDownloadStats() -> (count: Int, totalSpeed: Double) {
        guard let context = modelContext else { return (0, 0.0) }
        let descriptor = FetchDescriptor<DownloadItem>()
        let items = (try? context.fetch(descriptor)) ?? []
        let downloading = items.filter { $0.status == .downloading }
        let totalSpeed = downloading.reduce(0.0) { $0 + $1.currentSpeed }
        return (downloading.count, totalSpeed)
    }

    private func handleProgress(update: SegmentProgressUpdate, for itemId: UUID) {
        guard let context = modelContext, let item = activeItem(id: itemId, in: context) else { return }

        // Update segment model if exists, or create it
        if let seg = item.segments.first(where: { $0.segmentIndex == update.segmentIndex }) {
            seg.currentByte = update.currentByte
            seg.isCompleted = update.isCompleted
        } else {
            let newSeg = DownloadSegment(
                segmentIndex: update.segmentIndex,
                startByte: update.currentByte - update.bytesRead,
                endByte: update.currentByte,
                currentByte: update.currentByte,
                isCompleted: update.isCompleted
            )
            item.segments.append(newSeg)
        }

        item.downloadedBytes += update.bytesRead

        // Speed calculation
        if let sample = speedSamplers[itemId] {
            let now = Date()
            let timeDiff = now.timeIntervalSince(sample.timestamp)
            if timeDiff >= 0.5 {
                let bytesDiff = item.downloadedBytes - sample.bytes
                let speed = Double(bytesDiff) / timeDiff
                item.currentSpeed = max(0, speed)
                speedSamplers[itemId] = (bytes: item.downloadedBytes, timestamp: now)
            }
        }
    }

    private func handleComplete(for itemId: UUID) {
        guard let context = modelContext, let item = activeItem(id: itemId, in: context) else { return }
        item.status = .completed
        item.currentSpeed = 0
        if item.fileSize > 0 {
            item.downloadedBytes = item.fileSize
        }
        for seg in item.segments {
            seg.isCompleted = true
            seg.currentByte = seg.endByte + 1
        }
        try? context.save()
        activeTasks.removeValue(forKey: itemId)
        activeEngines.removeValue(forKey: itemId)
        speedSamplers.removeValue(forKey: itemId)
    }

    private func handleError(_ error: Error, for itemId: UUID) {
        guard let context = modelContext, let item = activeItem(id: itemId, in: context) else { return }
        item.status = .failed
        item.errorMessage = error.localizedDescription
        item.currentSpeed = 0
        try? context.save()
        activeTasks.removeValue(forKey: itemId)
        activeEngines.removeValue(forKey: itemId)
        speedSamplers.removeValue(forKey: itemId)
    }

    private func activeItem(id: UUID, in context: ModelContext) -> DownloadItem? {
        let descriptor = FetchDescriptor<DownloadItem>()
        let items = (try? context.fetch(descriptor)) ?? []
        return items.first(where: { $0.id == id })
    }
}
