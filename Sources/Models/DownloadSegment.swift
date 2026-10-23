import Foundation
import SwiftData

@Model
public final class DownloadSegment {
    public var id: UUID
    public var segmentIndex: Int
    public var startByte: Int64
    public var endByte: Int64
    public var currentByte: Int64
    public var isCompleted: Bool

    @Relationship(inverse: \DownloadItem.segments)
    public var downloadItem: DownloadItem?

    public init(
        id: UUID = UUID(),
        segmentIndex: Int,
        startByte: Int64,
        endByte: Int64,
        currentByte: Int64 = 0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.segmentIndex = segmentIndex
        self.startByte = startByte
        self.endByte = endByte
        self.currentByte = currentByte
        self.isCompleted = isCompleted
    }

    public var totalBytesInSegment: Int64 {
        max(0, endByte - startByte + 1)
    }

    public var downloadedInSegment: Int64 {
        if isCompleted {
            return totalBytesInSegment
        }
        return min(totalBytesInSegment, max(0, currentByte - startByte))
    }

    public var progress: Double {
        let total = totalBytesInSegment
        guard total > 0 else { return isCompleted ? 1.0 : 0.0 }
        return min(1.0, max(0.0, Double(downloadedInSegment) / Double(total)))
    }
}
