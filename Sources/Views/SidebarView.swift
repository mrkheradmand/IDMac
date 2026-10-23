import SwiftUI
import SwiftData

public enum SidebarFilter: Hashable, Identifiable {
    case all
    case status(DownloadStatus)
    case category(DownloadCategory)

    public var id: String {
        switch self {
        case .all: return "status_all"
        case .status(let stat): return "stat_\(stat.rawValue)"
        case .category(let cat): return "cat_\(cat.rawValue)"
        }
    }

    public var title: String {
        switch self {
        case .all: return "All Downloads"
        case .status(let stat): return stat.rawValue
        case .category(let cat): return cat.rawValue
        }
    }

    public var iconName: String {
        switch self {
        case .all: return "tray.full.fill"
        case .status(let stat): return stat.iconName
        case .category(let cat): return cat.iconName
        }
    }
}

@MainActor
public struct SidebarView: View {
    @Binding public var selection: SidebarFilter?
    @Query private var allDownloads: [DownloadItem]

    public init(selection: Binding<SidebarFilter?>) {
        self._selection = selection
    }

    public var body: some View {
        List(selection: $selection) {
            // Status on top with "All Downloads" first
            Section("Status") {
                NavigationLink(value: SidebarFilter.all) {
                    HStack {
                        Label("All Downloads", systemImage: "tray.full.fill")
                        Spacer()
                        Text("\(allDownloads.count)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }

                ForEach([DownloadStatus.downloading, .completed, .paused, .queued, .failed], id: \.self) { stat in
                    NavigationLink(value: SidebarFilter.status(stat)) {
                        HStack {
                            Label(stat.rawValue, systemImage: stat.iconName)
                            Spacer()
                            Text("\(count(forStatus: stat))")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Categories below Status, without "All Downloads"
            Section("Categories") {
                ForEach([DownloadCategory.compressed, .documents, .music, .programs, .video, .other], id: \.self) { cat in
                    NavigationLink(value: SidebarFilter.category(cat)) {
                        HStack {
                            Label(cat.rawValue, systemImage: cat.iconName)
                            Spacer()
                            Text("\(count(forCategory: cat))")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 190)
    }

    private func count(forCategory cat: DownloadCategory) -> Int {
        allDownloads.filter { $0.category == cat }.count
    }

    private func count(forStatus stat: DownloadStatus) -> Int {
        allDownloads.filter { $0.status == stat }.count
    }
}
