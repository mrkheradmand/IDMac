import SwiftUI
import SwiftData

public enum SidebarFilter: Hashable, Identifiable {
    case category(DownloadCategory)
    case status(DownloadStatus)

    public var id: String {
        switch self {
        case .category(let cat): return "cat_\(cat.rawValue)"
        case .status(let stat): return "stat_\(stat.rawValue)"
        }
    }

    public var title: String {
        switch self {
        case .category(let cat): return cat.rawValue
        case .status(let stat): return stat.rawValue
        }
    }

    public var iconName: String {
        switch self {
        case .category(let cat): return cat.iconName
        case .status(let stat): return stat.iconName
        }
    }
}

public struct SidebarView: View {
    @Binding public var selection: SidebarFilter?
    @Query private var allDownloads: [DownloadItem]

    public init(selection: Binding<SidebarFilter?>) {
        self._selection = selection
    }

    public var body: some View {
        List(selection: $selection) {
            Section("Categories") {
                ForEach([DownloadCategory.all, .compressed, .documents, .music, .programs, .video, .other], id: \.self) { cat in
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

            Section("Status") {
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
        }
        .listStyle(.sidebar)
        .frame(minWidth: 190)
    }

    private func count(forCategory cat: DownloadCategory) -> Int {
        if cat == .all {
            return allDownloads.count
        }
        return allDownloads.filter { $0.category == cat }.count
    }

    private func count(forStatus stat: DownloadStatus) -> Int {
        allDownloads.filter { $0.status == stat }.count
    }
}
