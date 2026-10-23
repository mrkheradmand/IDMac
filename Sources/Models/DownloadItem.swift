import Foundation
import SwiftData

@Model
public final class DownloadItem {
    @Attribute(.unique) public var id: UUID
    public var urlString: String
    public var filename: String
    public var fileSize: Int64
    public var downloadedBytes: Int64
    public var statusRaw: String
    public var categoryRaw: String
    public var dateAdded: Date
    public var destinationPath: String
    public var connectionCount: Int
    public var supportsResume: Bool
    public var errorMessage: String?
    public var currentSpeed: Double // bytes per second, ephemeral

    @Relationship(deleteRule: .cascade)
    public var segments: [DownloadSegment]

    public var status: DownloadStatus {
        get { DownloadStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }

    public var category: DownloadCategory {
        get { DownloadCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        urlString: String,
        filename: String = "",
        fileSize: Int64 = 0,
        downloadedBytes: Int64 = 0,
        status: DownloadStatus = .queued,
        category: DownloadCategory = .other,
        dateAdded: Date = Date(),
        destinationPath: String = "",
        connectionCount: Int = 8,
        supportsResume: Bool = false,
        errorMessage: String? = nil,
        currentSpeed: Double = 0.0
    ) {
        let resolvedFilename = filename.isEmpty ? (URL(string: urlString)?.lastPathComponent ?? "download") : filename
        self.id = id
        self.urlString = urlString
        self.filename = resolvedFilename
        self.fileSize = fileSize
        self.downloadedBytes = downloadedBytes
        self.statusRaw = status.rawValue
        self.categoryRaw = category == .all ? DownloadCategory.inferCategory(fromFilename: resolvedFilename).rawValue : category.rawValue
        self.dateAdded = dateAdded
        self.destinationPath = destinationPath
        self.connectionCount = connectionCount
        self.supportsResume = supportsResume
        self.errorMessage = errorMessage
        self.currentSpeed = currentSpeed
        self.segments = []
    }

    public var progress: Double {
        guard fileSize > 0 else { return status == .completed ? 1.0 : 0.0 }
        return min(1.0, max(0.0, Double(downloadedBytes) / Double(fileSize)))
    }

    public var formattedSize: String {
        FormatUtils.formatBytes(fileSize)
    }

    public var formattedDownloaded: String {
        FormatUtils.formatBytes(downloadedBytes)
    }

    public var formattedSpeed: String {
        status == .downloading ? FormatUtils.formatSpeed(currentSpeed) : "---"
    }

    public var formattedETA: String {
        guard status == .downloading, fileSize > 0 else { return "---" }
        let remaining = max(0, fileSize - downloadedBytes)
        return FormatUtils.formatETA(remainingBytes: remaining, bytesPerSec: currentSpeed)
    }
}
