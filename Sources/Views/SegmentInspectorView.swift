import SwiftUI

@MainActor
public struct SegmentInspectorView: View {
    public let item: DownloadItem

    public init(item: DownloadItem) {
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header summary
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.blue)
                Text("Connection Segments (\(item.connectionCount) streams)")
                    .font(.headline)

                Spacer()

                if item.supportsResume {
                    Label("Resume Capable", systemImage: "arrow.counterclockwise.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Direct Stream Only", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.bottom, 2)

            Divider()

            // Segments Grid / List
            if item.segments.isEmpty {
                VStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Allocating streams and probing byte ranges...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(item.segments.sorted(by: { $0.segmentIndex < $1.segmentIndex }), id: \.id) { seg in
                            HStack(spacing: 12) {
                                Text("Thread \(seg.segmentIndex + 1)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .frame(width: 75, alignment: .leading)

                                ClassicProgressBar(progress: seg.progress, height: 12, showPercentage: true)

                                Text("\(FormatUtils.formatBytes(seg.downloadedInSegment)) / \(FormatUtils.formatBytes(seg.totalBytesInSegment))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 140, alignment: .trailing)

                                if seg.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 12))
                                } else if item.status == .downloading {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.4))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 140)
            }

            Divider()

            // Metadata summary
            HStack(spacing: 16) {
                Text("Destination: \(item.destinationPath)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if let err = item.errorMessage {
                    Text("Error: \(err)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .top
        )
    }
}
