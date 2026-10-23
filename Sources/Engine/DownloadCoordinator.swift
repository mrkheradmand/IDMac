import Foundation
import SwiftUI
import SwiftData
import AppKit

public enum DuplicateResolution: Sendable {
    case autoRename(String)
    case overwrite
    case cancel
}

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

    @discardableResult
    public func addDownload(
        urlString: String,
        customFilename: String? = nil,
        destinationFolder: URL,
        connectionCount: Int = 8,
        modelContext: ModelContext,
        startImmediately: Bool = true
    ) async -> Bool {
        self.modelContext = modelContext
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }

        var detectedFilename = customFilename ?? url.lastPathComponent
        if detectedFilename.isEmpty {
            detectedFilename = "download_\(Int(Date().timeIntervalSince1970))"
        }
        var totalSize: Int64 = 0
        var supportsResume = false

        do {
            let probe = try await DownloadEngine.probe(url: url)
            if customFilename == nil || customFilename!.isEmpty {
                detectedFilename = probe.filename
            }
            totalSize = probe.totalSize
            supportsResume = probe.supportsResume
        } catch {
            print("Probe error: \(error.localizedDescription), proceeding with defaults")
        }

        var destinationURL = destinationFolder.appendingPathComponent(detectedFilename)

        // Duplicate Detection: Check list and filesystem
        let duplicateItem = findDuplicateItem(urlString: urlString, destinationPath: destinationURL.path, in: modelContext)
        let fileExistsOnDisk = FileManager.default.fileExists(atPath: destinationURL.path)

        if duplicateItem != nil || fileExistsOnDisk {
            let resolution = await promptDuplicateAction(
                filename: detectedFilename,
                destinationFolder: destinationFolder,
                existingItem: duplicateItem,
                fileExistsOnDisk: fileExistsOnDisk
            )

            switch resolution {
            case .cancel:
                return false

            case .autoRename(let uniqueName):
                detectedFilename = uniqueName
                destinationURL = destinationFolder.appendingPathComponent(detectedFilename)

            case .overwrite:
                if let existing = duplicateItem {
                    delete(item: existing, deleteFile: true, modelContext: modelContext)
                } else if fileExistsOnDisk {
                    try? FileManager.default.removeItem(at: destinationURL)
                }
            }
        }

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

        return true
    }

    private func findDuplicateItem(urlString: String, destinationPath: String, in context: ModelContext) -> DownloadItem? {
        let descriptor = FetchDescriptor<DownloadItem>()
        let items = (try? context.fetch(descriptor)) ?? []

        // Priority 1: Identical destination path on disk
        if let match = items.first(where: { $0.destinationPath.lowercased() == destinationPath.lowercased() }) {
            return match
        }

        // Priority 2: Identical source URL
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = items.first(where: { $0.urlString.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedURL }) {
            return match
        }

        // Priority 3: Identical filename
        let filename = URL(fileURLWithPath: destinationPath).lastPathComponent
        if let match = items.first(where: { $0.filename.lowercased() == filename.lowercased() }) {
            return match
        }

        return nil
    }

    private func generateUniqueFilename(baseName: String, in folder: URL) -> String {
        let url = URL(fileURLWithPath: baseName)
        let ext = url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent

        let descriptor = FetchDescriptor<DownloadItem>()
        let existingItems = (try? modelContext?.fetch(descriptor)) ?? []

        var index = 1
        while true {
            let candidate = ext.isEmpty ? "\(stem) (\(index))" : "\(stem) (\(index)).\(ext)"
            let candidateURL = folder.appendingPathComponent(candidate)
            let existsOnDisk = FileManager.default.fileExists(atPath: candidateURL.path)
            let existsInList = existingItems.contains {
                $0.destinationPath.lowercased() == candidateURL.path.lowercased() || $0.filename.lowercased() == candidate.lowercased()
            }

            if !existsOnDisk && !existsInList {
                return candidate
            }
            index += 1
        }
    }

    @MainActor
    private func promptDuplicateAction(
        filename: String,
        destinationFolder: URL,
        existingItem: DownloadItem?,
        fileExistsOnDisk: Bool
    ) async -> DuplicateResolution {
        // Ensure IDMac is active and main window is displayed
        MenuBarManager.shared.showMainWindow()
        NSApp.activate(ignoringOtherApps: true)

        let targetPath = destinationFolder.appendingPathComponent(filename).path

        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "Duplicate Download Detected"
            alert.alertStyle = .warning

            if let appIcon = NSApp.applicationIconImage {
                alert.icon = appIcon
            }

            var infoParts: [String] = []

            if let existing = existingItem {
                let sizeStr = existing.fileSize > 0 ? " (\(FormatUtils.formatBytes(existing.fileSize)))" : ""
                switch existing.status {
                case .completed:
                    infoParts.append("The file \"\(filename)\" has already been downloaded and is in your download list.")
                    infoParts.append("• Status: Completed\(sizeStr)")
                case .downloading, .connecting:
                    let pct = existing.fileSize > 0 ? " (\(Int(Double(existing.downloadedBytes) / Double(existing.fileSize) * 100))%)" : ""
                    infoParts.append("The file \"\(filename)\" is currently downloading in IDMac.")
                    infoParts.append("• Status: Downloading in progress\(pct)")
                case .paused:
                    infoParts.append("The file \"\(filename)\" is in your download list (Paused).")
                    infoParts.append("• Status: Paused\(sizeStr)")
                case .queued:
                    infoParts.append("The file \"\(filename)\" is in your download list (Queued).")
                    infoParts.append("• Status: Queued\(sizeStr)")
                case .failed:
                    infoParts.append("The file \"\(filename)\" is in your download list (Failed).")
                    infoParts.append("• Status: Failed previously")
                }
            } else if fileExistsOnDisk {
                infoParts.append("A file named \"\(filename)\" already exists in your destination folder.")
            }

            if fileExistsOnDisk {
                infoParts.append("• Location: \(targetPath)")
            }

            infoParts.append("\nWhat would you like to do?")
            alert.informativeText = infoParts.joined(separator: "\n")

            // Button 1 (Default / Key Equivalent: Return): Auto-Rename (Keep Both)
            let renameBtn = alert.addButton(withTitle: "Auto-Rename (Keep Both)")
            renameBtn.keyEquivalent = "\r"

            // Button 2: Overwrite
            alert.addButton(withTitle: "Overwrite")

            // Button 3 (Key Equivalent: Escape): Cancel
            let cancelBtn = alert.addButton(withTitle: "Cancel")
            cancelBtn.keyEquivalent = "\u{1b}"

            // Button 4: Reveal in Finder (if file exists on disk)
            if fileExistsOnDisk {
                alert.addButton(withTitle: "Reveal in Finder")
            }

            let handleResponse = { (response: NSApplication.ModalResponse) in
                switch response {
                case .alertFirstButtonReturn: // Auto-Rename
                    let uniqueName = self.generateUniqueFilename(baseName: filename, in: destinationFolder)
                    continuation.resume(returning: .autoRename(uniqueName))

                case .alertSecondButtonReturn: // Overwrite
                    continuation.resume(returning: .overwrite)

                case .alertThirdButtonReturn: // Cancel
                    continuation.resume(returning: .cancel)

                default: // Fourth button (1003): Reveal in Finder
                    NSWorkspace.shared.selectFile(targetPath, inFileViewerRootedAtPath: destinationFolder.path)
                    continuation.resume(returning: .cancel)
                }
            }

            if let window = NSApp.windows.first(where: { $0.isVisible && !$0.isFloatingPanel && $0.canBecomeKey }),
               window.attachedSheet == nil {
                alert.beginSheetModal(for: window) { response in
                    handleResponse(response)
                }
            } else {
                let response = alert.runModal()
                handleResponse(response)
            }
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

        // Ensure segments are properly initialized with accurate byte ranges before starting workers
        if item.segments.isEmpty {
            let count = (item.supportsResume && item.fileSize > 0) ? max(1, item.connectionCount) : 1
            let total = item.fileSize
            if count > 1 && total > 0 {
                let chunkSize = total / Int64(count)
                for i in 0..<count {
                    let start = Int64(i) * chunkSize
                    let end = (i == count - 1) ? (total - 1) : (start + chunkSize - 1)
                    let seg = DownloadSegment(
                        segmentIndex: i,
                        startByte: start,
                        endByte: end,
                        currentByte: start,
                        isCompleted: false
                    )
                    item.segments.append(seg)
                }
            } else {
                let seg = DownloadSegment(
                    segmentIndex: 0,
                    startByte: 0,
                    endByte: max(0, total - 1),
                    currentByte: 0,
                    isCompleted: false
                )
                item.segments.append(seg)
            }
        }
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
            let total = item.fileSize
            let count = max(1, item.connectionCount)
            let chunkSize = total > 0 ? (total / Int64(count)) : 0
            let start = Int64(update.segmentIndex) * chunkSize
            let end = (update.segmentIndex == count - 1) ? max(0, total - 1) : (start + chunkSize - 1)
            let newSeg = DownloadSegment(
                segmentIndex: update.segmentIndex,
                startByte: start,
                endByte: max(start, end),
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
            seg.currentByte = seg.endByte
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
