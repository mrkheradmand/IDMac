import SwiftUI
import SwiftData

public struct MainSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DownloadItem.dateAdded, order: .reverse) private var allDownloads: [DownloadItem]

    @State private var selectedFilter: SidebarFilter? = .category(.all)
    @State private var selectedDownloadId: UUID?
    @State private var searchText = ""
    @State private var isAddSheetPresented = false
    @State private var isSettingsSheetPresented = false

    private var coordinator = DownloadCoordinator.shared

    public init() {}

    private var filteredDownloads: [DownloadItem] {
        var items = allDownloads

        if let filter = selectedFilter {
            switch filter {
            case .category(let cat):
                if cat != .all {
                    items = items.filter { $0.category == cat }
                }
            case .status(let stat):
                items = items.filter { $0.status == stat }
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

    private var selectedItem: DownloadItem? {
        guard let id = selectedDownloadId else { return nil }
        return allDownloads.first(where: { $0.id == id })
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
                        Text("No Downloads in this Category")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Add URL to Download") {
                            isAddSheetPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    DownloadTableView(items: filteredDownloads, selection: $selectedDownloadId)
                }

                // Bottom Segment Inspector (Classic multi-part threads view)
                if let item = selectedItem {
                    SegmentInspectorView(item: item)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
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
                    if let item = selectedItem {
                        coordinator.resume(item: item, modelContext: modelContext)
                    }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .disabled(selectedItem == nil || selectedItem?.status == .downloading || selectedItem?.status == .completed)
                .help("Resume selected download")

                Button {
                    if let item = selectedItem {
                        coordinator.pause(item: item, modelContext: modelContext)
                    }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .disabled(selectedItem == nil || selectedItem?.status != .downloading)
                .help("Pause selected download")

                Button {
                    coordinator.pauseAll(items: allDownloads, modelContext: modelContext)
                } label: {
                    Label("Stop All", systemImage: "stop.fill")
                }
                .help("Stop/Pause all active downloads")

                Divider()

                Button {
                    if let item = selectedItem {
                        coordinator.delete(item: item, deleteFile: false, modelContext: modelContext)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedItem == nil)
                .help("Remove download from list")
            }
        }
        .searchable(text: $searchText, prompt: "Search files or URLs...")
        .sheet(isPresented: $isAddSheetPresented) {
            AddDownloadSheet()
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsView()
        }
    }
}
