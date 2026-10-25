import SwiftUI
import SwiftData
import Combine

@MainActor
public struct MainSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DownloadItem.dateAdded, order: .reverse) private var allDownloads: [DownloadItem]

    @State private var selectedFilter: SidebarFilter? = .all
    @State private var selectedDownloadIds: Set<UUID> = []
    @State private var searchText = ""
    @State private var isAddSheetPresented = false
    @State private var isSettingsSheetPresented = false
    private let diskCheckTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private var coordinator: DownloadCoordinator {
        DownloadCoordinator.shared
    }

    public init() {}

    private var filteredDownloads: [DownloadItem] {
        var items = allDownloads

        if let filter = selectedFilter {
            switch filter {
            case .all:
                break
            case .status(let stat):
                items = items.filter { $0.status == stat }
            case .category(let cat):
                items = items.filter { $0.category == cat }
            }
        }

        if !searchText.isEmpty {
            items = items.filter {
                $0.filename.localizedCaseInsensitiveContains(searchText) ||
                $0.urlString.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    private var emptyStateTitle: String {
        if let filter = selectedFilter {
            switch filter {
            case .all:
                return "No Downloads"
            case .status(let stat):
                return "No \(stat.rawValue) Downloads"
            case .category(let cat):
                return "No \(cat.rawValue) Downloads"
            }
        }
        return "No Downloads"
    }

    private var selectedItems: [DownloadItem] {
        allDownloads.filter { selectedDownloadIds.contains($0.id) }
    }

    private var selectedItem: DownloadItem? {
        if selectedDownloadIds.count == 1, let id = selectedDownloadIds.first {
            return allDownloads.first(where: { $0.id == id })
        }
        return nil
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedFilter)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            VStack(spacing: 0) {
                // Main Downloads Table
                if filteredDownloads.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text(emptyStateTitle)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Add URL to Download") {
                            isAddSheetPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    DownloadTableView(items: filteredDownloads, selection: $selectedDownloadIds)
                }

                // Bottom Segment Inspector (Classic multi-part threads view)
                if let item = selectedItem {
                    SegmentInspectorView(item: item)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onDeleteCommand {
            deleteSelectedFromList()
        }
        .background {
            // Forward delete (Fn+Delete or external keyboard delete)
            Button(action: deleteSelectedFromList) {
                EmptyView()
            }
            .keyboardShortcut(.deleteForward, modifiers: [])
            .hidden()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isAddSheetPresented = true
                } label: {
                    Label("Add URL", systemImage: "plus.circle.fill")
                }
                .help("Add new download URL")

                Divider()

                Button {
                    let resumable = selectedItems.filter { $0.status == .paused || $0.status == .queued || $0.status == .failed || $0.status == .deleted }
                    for item in resumable {
                        coordinator.resume(item: item, modelContext: modelContext)
                    }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .disabled(selectedItems.filter { $0.status == .paused || $0.status == .queued || $0.status == .failed || $0.status == .deleted }.isEmpty)
                .help("Resume selected downloads")

                Button {
                    let downloadable = selectedItems.filter { $0.status == .downloading || $0.status == .connecting }
                    for item in downloadable {
                        coordinator.pause(item: item, modelContext: modelContext)
                    }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .disabled(selectedItems.filter { $0.status == .downloading || $0.status == .connecting }.isEmpty)
                .help("Pause selected downloads")

                Button {
                    coordinator.pauseAll(items: allDownloads, modelContext: modelContext)
                } label: {
                    Label("Stop All", systemImage: "stop.fill")
                }
                .help("Stop/Pause all active downloads")

                Divider()

                Button {
                    deleteSelectedFromList()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedDownloadIds.isEmpty)
                .keyboardShortcut(.delete, modifiers: [])
                .help("Remove selected downloads from list (Delete)")
            }

            ToolbarItem(placement: .primaryAction) {
                NativeSearchField(text: $searchText, prompt: "Search files or URLs...")
                    .frame(width: 220)
            }
        }
        .sheet(isPresented: Binding(
            get: { isAddSheetPresented || coordinator.isAddingDownloadSheetPresented },
            set: { val in
                isAddSheetPresented = val
                coordinator.isAddingDownloadSheetPresented = val
            }
        )) {
            AddDownloadSheet()
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsView()
        }
        .onAppear {
            coordinator.modelContext = modelContext
            coordinator.verifyDiskFiles(in: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            coordinator.verifyDiskFiles(in: modelContext)
        }
        .onReceive(diskCheckTimer) { _ in
            coordinator.verifyDiskFiles(in: modelContext)
        }
    }

    private func deleteSelectedFromList() {
        let itemsToDelete = selectedItems
        guard !itemsToDelete.isEmpty else { return }
        coordinator.delete(items: itemsToDelete, deleteFile: false, modelContext: modelContext)
        selectedDownloadIds.removeAll()
    }
}
