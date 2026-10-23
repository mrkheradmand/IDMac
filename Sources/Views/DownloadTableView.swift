import SwiftUI
import SwiftData
import AppKit

public struct DownloadTableView: View {
    public let items: [DownloadItem]
    @Binding public var selection: UUID?

    @Environment(\.modelContext) private var modelContext
    private var coordinator = DownloadCoordinator.shared

    public init(items: [DownloadItem], selection: Binding<UUID?>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        Table(items, selection: $selection) {
            TableColumn("File Name") { item in
                HStack(spacing: 8) {
                    Image(systemName: item.category.iconName)
                        .foregroundColor(.accentColor)
                        .frame(width: 16)
                    Text(item.filename)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            .width(min: 160, ideal: 240)

            TableColumn("Size") { item in
                Text(item.formattedSize)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(ideal: 85)

            TableColumn("Status") { item in
                StatusBadge(status: item.status)
            }
            .width(ideal: 110)

            TableColumn("Progress") { item in
                ClassicProgressBar(progress: item.progress, height: 14, showPercentage: true)
            }
            .width(min: 120, ideal: 180)

            TableColumn("Speed") { item in
                Text(item.formattedSpeed)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(item.status == .downloading ? .blue : .secondary)
            }
            .width(ideal: 90)

            TableColumn("Time Left") { item in
                Text(item.formattedETA)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(ideal: 85)

            TableColumn("Resume") { item in
                Text(item.supportsResume ? "Yes" : "No")
                    .font(.system(size: 11))
                    .foregroundColor(item.supportsResume ? .green : .orange)
            }
            .width(ideal: 65)

            TableColumn("Date Added") { item in
                Text(item.dateAdded.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .width(ideal: 130)
        }
        .contextMenu(forSelectionType: UUID.self) { selectedIds in
            if let firstId = selectedIds.first, let item = items.first(where: { $0.id == firstId }) {
                contextMenuContent(for: item)
            }
        } primaryAction: { selectedIds in
            if let firstId = selectedIds.first, let item = items.first(where: { $0.id == firstId }) {
                handlePrimaryAction(for: item)
            }
        }
    }

    @ViewBuilder
    private func contextMenuContent(for item: DownloadItem) -> some View {
        if item.status == .downloading {
            Button("Pause Download") {
                coordinator.pause(item: item, modelContext: modelContext)
            }
        } else if item.status == .paused || item.status == .queued || item.status == .failed {
            Button("Resume Download") {
                coordinator.resume(item: item, modelContext: modelContext)
            }
        }

        Divider()

        if item.status == .completed {
            Button("Open File") {
                NSWorkspace.shared.open(URL(fileURLWithPath: item.destinationPath))
            }
        }

        Button("Show in Finder") {
            let url = URL(fileURLWithPath: item.destinationPath)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        Button("Copy Download Link") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.urlString, forType: .string)
        }

        Divider()

        Button("Redownload") {
            item.downloadedBytes = 0
            item.status = .queued
            for seg in item.segments {
                seg.currentByte = seg.startByte
                seg.isCompleted = false
            }
            coordinator.start(item: item, modelContext: modelContext)
        }

        Divider()

        Button("Remove from List", role: .destructive) {
            coordinator.delete(item: item, deleteFile: false, modelContext: modelContext)
        }

        Button("Delete File and Remove", role: .destructive) {
            coordinator.delete(item: item, deleteFile: true, modelContext: modelContext)
        }
    }

    private func handlePrimaryAction(for item: DownloadItem) {
        if item.status == .completed {
            NSWorkspace.shared.open(URL(fileURLWithPath: item.destinationPath))
        } else if item.status == .downloading {
            coordinator.pause(item: item, modelContext: modelContext)
        } else {
            coordinator.resume(item: item, modelContext: modelContext)
        }
    }
}
