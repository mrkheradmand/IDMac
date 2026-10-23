import SwiftUI

public struct SettingsView: View {
    @AppStorage("defaultConnections") private var defaultConnections: Int = 8
    @AppStorage("autoCheckClipboard") private var autoCheckClipboard: Bool = true
    @AppStorage("playCompletionSound") private var playCompletionSound: Bool = true
    @AppStorage("maxConcurrentDownloads") private var maxConcurrentDownloads: Int = 3

    public init() {}

    public var body: some View {
        TabView {
            Form {
                Section("Connection & Performance") {
                    Picker("Default Connection Streams:", selection: $defaultConnections) {
                        Text("1 (Single stream)").tag(1)
                        Text("4 streams").tag(4)
                        Text("8 streams (Recommended)").tag(8)
                        Text("16 streams").tag(16)
                        Text("32 streams (High bandwidth)").tag(32)
                    }

                    Picker("Max Active Downloads:", selection: $maxConcurrentDownloads) {
                        Text("1 download").tag(1)
                        Text("2 downloads").tag(2)
                        Text("3 downloads").tag(3)
                        Text("5 downloads").tag(5)
                        Text("Unlimited").tag(100)
                    }
                }

                Section("Automation") {
                    Toggle("Monitor clipboard for new download links", isOn: $autoCheckClipboard)
                    Toggle("Play sound when download finishes", isOn: $playCompletionSound)
                }

                Section("Default Storage") {
                    HStack {
                        Text("Downloads Folder:")
                        Spacer()
                        Text("~/Downloads")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(width: 450, height: 280)
    }
}
