import SwiftUI

public struct StatusBadge: View {
    public let status: DownloadStatus

    public init(status: DownloadStatus) {
        self.status = status
    }

    private var statusColor: Color {
        switch status {
        case .downloading, .connecting: return .blue
        case .completed: return .green
        case .paused: return .orange
        case .queued: return .gray
        case .failed: return .red
        }
    }

    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(statusColor)

            Text(status.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.12))
        .cornerRadius(4)
    }
}
