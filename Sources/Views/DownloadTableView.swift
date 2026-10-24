import SwiftUI
import SwiftData
import AppKit

@MainActor
public struct DownloadTableView: View {
    public let items: [DownloadItem]
    @Binding public var selection: Set<UUID>

    @Environment(\.modelContext) private var modelContext
    private var coordinator: DownloadCoordinator {
        DownloadCoordinator.shared
    }

    public init(items: [DownloadItem], selection: Binding<Set<UUID>>) {
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
            .width(min: 140, ideal: 200)

            TableColumn("Size") { item in
                Text(item.formattedSize)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(min: 55, ideal: 70)

            TableColumn("Status") { item in
                StatusBadge(status: item.status)
            }
            .width(min: 75, ideal: 90)

            TableColumn("Progress") { item in
                ClassicProgressBar(progress: item.progress, height: 14, showPercentage: true)
            }
            .width(min: 90, ideal: 130)

            TableColumn("Speed") { item in
                Text(item.formattedSpeed)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(item.status == .downloading ? .blue : .secondary)
            }
            .width(min: 60, ideal: 75)

            TableColumn("Time Left") { item in
                Text(item.formattedETA)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(min: 60, ideal: 75)

            TableColumn("Resume") { item in
                Text(item.supportsResume ? "Yes" : "No")
                    .font(.system(size: 11))
                    .foregroundColor(item.supportsResume ? .green : .orange)
            }
            .width(min: 50, ideal: 60)

            TableColumn("Date Added") { item in
                Text(item.dateAdded.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .width(min: 90, ideal: 110)
        }
        .scrollIndicators(.never, axes: .horizontal)
        .onDeleteCommand {
            deleteSelectedFromList()
        }
        .contextMenu(forSelectionType: UUID.self) { selectedIds in
            let effectiveIds = selectedIds.isEmpty ? selection : selectedIds
            let targetItems = items.filter { effectiveIds.contains($0.id) }
            if !targetItems.isEmpty {
                contextMenuContent(for: targetItems, targetIds: effectiveIds)
            }
        } primaryAction: { selectedIds in
            if let firstId = selectedIds.first, let item = items.first(where: { $0.id == firstId }) {
                handlePrimaryAction(for: item)
            }
        }
    }

    @ViewBuilder
    private func contextMenuContent(for targetItems: [DownloadItem], targetIds: Set<UUID>) -> some View {
        let activeItems = targetItems.filter { $0.status == .downloading || $0.status == .connecting }
        let resumableItems = targetItems.filter { $0.status == .paused || $0.status == .queued || $0.status == .failed }

        if !activeItems.isEmpty {
            Button(activeItems.count > 1 ? "Pause \(activeItems.count) Downloads" : "Pause Download") {
                for item in activeItems {
                    coordinator.pause(item: item, modelContext: modelContext)
                }
            }
        }

        if !resumableItems.isEmpty {
            Button(resumableItems.count > 1 ? "Resume \(resumableItems.count) Downloads" : "Resume Download") {
                for item in resumableItems {
                    coordinator.resume(item: item, modelContext: modelContext)
                }
            }
        }

        if !activeItems.isEmpty || !resumableItems.isEmpty {
            Divider()
        }

        if targetItems.count == 1, let singleItem = targetItems.first, singleItem.status == .completed {
            Button("Open File") {
                NSWorkspace.shared.open(URL(fileURLWithPath: singleItem.destinationPath))
            }
        }

        Button(targetItems.count > 1 ? "Show in Finder (\(targetItems.count) Files)" : "Show in Finder") {
            let urls = targetItems.map { URL(fileURLWithPath: $0.destinationPath) }
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }

        Button(targetItems.count > 1 ? "Copy Download Links (\(targetItems.count))" : "Copy Download Link") {
            let links = targetItems.map { $0.urlString }.joined(separator: "\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(links, forType: .string)
        }

        Divider()

        Button(targetItems.count > 1 ? "Redownload (\(targetItems.count) Items)" : "Redownload") {
            for item in targetItems {
                item.downloadedBytes = 0
                item.status = .queued
                for seg in item.segments {
                    seg.currentByte = seg.startByte
                    seg.isCompleted = false
                }
                coordinator.start(item: item, modelContext: modelContext)
            }
        }

        Divider()

        Button(targetItems.count > 1 ? "Remove \(targetItems.count) Items from List" : "Remove from List", role: .destructive) {
            coordinator.delete(items: targetItems, deleteFile: false, modelContext: modelContext)
            selection.subtract(targetIds)
        }

        Button(targetItems.count > 1 ? "Delete \(targetItems.count) Files and Remove" : "Delete File and Remove", role: .destructive) {
            coordinator.delete(items: targetItems, deleteFile: true, modelContext: modelContext)
            selection.subtract(targetIds)
        }
    }

    private func deleteSelectedFromList() {
        let targetItems = items.filter { selection.contains($0.id) }
        guard !targetItems.isEmpty else { return }
        coordinator.delete(items: targetItems, deleteFile: false, modelContext: modelContext)
        selection.subtract(targetItems.map { $0.id })
    }

    @MainActor
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
