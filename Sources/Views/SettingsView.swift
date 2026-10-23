import SwiftUI
import AppKit

@MainActor
public struct SettingsView: View {
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)

            AccelerationSettingsTab()
                .tabItem {
                    Label("Acceleration", systemImage: "bolt.horizontal")
                }
                .tag(1)

            UpdatesSettingsTab()
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(2)

            AdvancedSettingsTab()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .tag(3)
        }
        .frame(width: 560, height: 530)
    }
}

// MARK: - 1. General Settings Tab
private struct GeneralSettingsTab: View {
    @ObservedObject private var launchManager = LaunchAtLoginManager.shared
    @AppStorage("defaultDownloadDirectory") private var defaultDownloadDirectory: String = ""
    @AppStorage("autoCheckClipboard") private var autoCheckClipboard: Bool = true
    @AppStorage("playCompletionSound") private var playCompletionSound: Bool = true
    @AppStorage("showNotifications") private var showNotifications: Bool = true
    @AppStorage("preventSystemSleep") private var preventSystemSleep: Bool = true
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true
    @AppStorage("keepRunningInMenuBar") private var keepRunningInMenuBar: Bool = true
    @AppStorage("hideDockIconWhenClosed") private var hideDockIconWhenClosed: Bool = true

    private var resolvedDirectoryDisplay: String {
        if defaultDownloadDirectory.isEmpty {
            return "~/Downloads"
        }
        let home = NSHomeDirectory()
        if defaultDownloadDirectory.hasPrefix(home) {
            return defaultDownloadDirectory.replacingOccurrences(of: home, with: "~")
        }
        return defaultDownloadDirectory
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16))

                        Text(resolvedDirectoryDisplay)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Change…") {
                            chooseDownloadFolder()
                        }
                        .controlSize(.small)

                        if !defaultDownloadDirectory.isEmpty {
                            Button("Reset") {
                                defaultDownloadDirectory = ""
                            }
                            .controlSize(.small)
                        }
                    }

                    Text("Newly queued downloads will automatically save into this folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Default Download Location")
            }

            Section {
                Toggle(isOn: $autoCheckClipboard) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monitor clipboard for downloadable links")
                            .font(.system(size: 13))
                        Text("Automatically detects URLs when copying web links to the clipboard.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $playCompletionSound) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Play completion sound")
                            .font(.system(size: 13))
                        Text("Plays a subtle system chime when all segments finish merging.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $showNotifications) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show notification banner")
                            .font(.system(size: 13))
                        Text("Sends a native macOS notification alert when items complete.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Automation & Notifications")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { launchManager.isEnabled },
                    set: { launchManager.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch IDMac at system startup")
                            .font(.system(size: 13))
                        Text("Automatically start IDMac in the background when logging into macOS.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $showMenuBarIcon) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show status icon in menu bar")
                            .font(.system(size: 13))
                        Text("Displays quick download status and controls in the macOS menu bar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: showMenuBarIcon) { _, _ in
                    MenuBarManager.shared.setupStatusBarItem()
                }

                if showMenuBarIcon {
                    Toggle(isOn: $keepRunningInMenuBar) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep IDMac running in menu bar when window is closed")
                                .font(.system(size: 13))
                            Text("Closing the main window leaves IDMac running in the background.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if keepRunningInMenuBar {
                        Toggle(isOn: $hideDockIconWhenClosed) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hide Dock icon when window is closed")
                                    .font(.system(size: 13))
                                Text("Removes IDMac from the Dock and Cmd+Tab switcher while window is closed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Menu Bar & System Startup")
            }

            Section {
                Toggle(isOn: $preventSystemSleep) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Prevent Mac from sleeping during downloads")
                            .font(.system(size: 13))
                        Text("Keeps network and storage active while segmented streams are transferring.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Power Management")
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private func chooseDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Folder"
        panel.title = "Select Default Download Directory"

        if panel.runModal() == .OK, let url = panel.url {
            defaultDownloadDirectory = url.path
        }
    }
}

// MARK: - 2. Acceleration Settings Tab
private struct AccelerationSettingsTab: View {
    @AppStorage("defaultConnections") private var defaultConnections: Int = 8
    @AppStorage("maxConcurrentDownloads") private var maxConcurrentDownloads: Int = 3
    @AppStorage("networkTimeout") private var networkTimeout: Int = 15
    @AppStorage("maxRetryAttempts") private var maxRetryAttempts: Int = 3
    @AppStorage("bufferChunkSize") private var bufferChunkSize: Int = 262144

    var body: some View {
        Form {
            Section {
                Picker("Default stream count:", selection: $defaultConnections) {
                    Text("1 stream (Single stream)").tag(1)
                    Text("2 streams").tag(2)
                    Text("4 streams").tag(4)
                    Text("8 streams (Recommended)").tag(8)
                    Text("16 streams (High speed)").tag(16)
                    Text("24 streams").tag(24)
                    Text("32 streams (Extreme bandwidth)").tag(32)
                }

                Text("Splits downloadable files into concurrent HTTP byte-range streams for maximum acceleration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Maximum active downloads:", selection: $maxConcurrentDownloads) {
                    Text("1 download").tag(1)
                    Text("2 downloads").tag(2)
                    Text("3 downloads (Default)").tag(3)
                    Text("5 downloads").tag(5)
                    Text("10 downloads").tag(10)
                    Text("Unlimited").tag(100)
                }

                Text("Controls how many downloads run simultaneously before queuing remaining items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Multi-Stream Concurrency")
            }

            Section {
                Picker("Socket timeout:", selection: $networkTimeout) {
                    Text("10 seconds").tag(10)
                    Text("15 seconds (Recommended)").tag(15)
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                }

                Picker("Retry attempts on network failure:", selection: $maxRetryAttempts) {
                    Text("Never").tag(0)
                    Text("1 attempt").tag(1)
                    Text("3 attempts (Recommended)").tag(3)
                    Text("5 attempts").tag(5)
                    Text("10 attempts").tag(10)
                }

                Text("Automatically re-establishes broken or throttled HTTP socket connections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Network Resilience")
            }

            Section {
                Picker("Stream buffer chunk size:", selection: $bufferChunkSize) {
                    Text("64 KB").tag(65536)
                    Text("128 KB").tag(131072)
                    Text("256 KB (Recommended)").tag(262144)
                    Text("512 KB").tag(524288)
                    Text("1 MB (High throughput)").tag(1048576)
                }

                Text("In-memory streaming buffer allocated per active connection thread before writing to disk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Memory Buffering")
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

// MARK: - 3. Updates Settings Tab
private struct UpdatesSettingsTab: View {
    @ObservedObject private var updateManager = UpdateManager.shared
    @AppStorage("automaticallyCheckForUpdates") private var automaticallyCheckForUpdates: Bool = true
    @AppStorage("updateCheckFrequency") private var updateCheckFrequency: String = "daily"
    @AppStorage("includePreReleases") private var includePreReleases: Bool = false

    private let repoURL = URL(string: "https://github.com/mrkheradmand/IDMac")!

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        if let icon = NSApp.applicationIconImage {
                            Image(nsImage: icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("IDMac")
                                .font(.system(size: 14, weight: .bold))

                            Text("Version \(updateManager.currentVersion) (Build \(updateManager.currentBuild))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Check Now") {
                            Task {
                                await updateManager.checkForUpdates(manual: true)
                            }
                        }
                        .disabled(updateManager.state == .checking)
                        .controlSize(.regular)
                    }

                    Divider()

                    // Dynamic status presentation
                    statusBanner
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            } header: {
                Text("Update Status")
            }

            Section {
                Toggle(isOn: $automaticallyCheckForUpdates) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatically check for updates")
                            .font(.system(size: 13))
                        Text("Periodically queries GitHub releases in the background on startup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if automaticallyCheckForUpdates {
                    Picker("Check frequency:", selection: $updateCheckFrequency) {
                        Text("Every launch").tag("launch")
                        Text("Daily (Recommended)").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }

                    Toggle(isOn: $includePreReleases) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include pre-releases & beta versions")
                                .font(.system(size: 13))
                            Text("Get early access to preview builds and experimental features.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Automatic Updates")
            }

            Section {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Updates are verified with SHA256 checksums and downloaded directly from official GitHub releases.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Verification & Security")
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch updateManager.state {
        case .idle:
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                if let last = updateManager.lastChecked {
                    Text("Last checked: \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No update checks performed yet in this session.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

        case .checking:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking GitHub for the latest release…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }

        case .upToDate:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text("IDMac is up to date.")
                        .font(.system(size: 12, weight: .semibold))
                    if let last = updateManager.lastChecked {
                        Text("Last checked: \(last.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

        case .available(let update):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                    Text("IDMac \(update.version) is available!")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button("Download & Install Update") {
                        updateManager.downloadAndApplyUpdate(update: update)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Link("Release Notes", destination: update.releaseURL)
                        .font(.system(size: 11))
                }
            }
            .padding(10)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(6)

        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Downloading update DMG…")
                        .font(.system(size: 12))
                    Spacer()
                    if progress > 0 {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                if progress > 0 {
                    ProgressView(value: progress)
                        .controlSize(.small)
                }
            }

        case .readyToInstall:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("Update downloaded. Disk image opened in Finder.")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }

        case .error(let msg):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
            }
        }
    }
}

// MARK: - 4. Advanced Settings Tab
private struct AdvancedSettingsTab: View {
    @AppStorage("preallocationMode") private var preallocationMode: String = "sparse"
    @AppStorage("enableSpeedLimit") private var enableSpeedLimit: Bool = false
    @AppStorage("speedLimitKBps") private var speedLimitKBps: Int = 2048

    @State private var showingResetAlert = false

    var body: some View {
        Form {
            Section {
                Picker("File pre-allocation:", selection: $preallocationMode) {
                    Text("Sparse File Allocation (Instant start)").tag("sparse")
                    Text("Full Pre-allocation via fcntl (Zero fragmentation)").tag("full")
                }

                Text("Sparse allocation creates empty space instantaneously. Full allocation reserves contiguous disk blocks via fcntl(F_PREALLOCATE) on APFS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Disk Storage & Allocation")
            }

            Section {
                Toggle(isOn: $enableSpeedLimit) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Limit overall download speed")
                            .font(.system(size: 13))
                        Text("Throttles total throughput to avoid saturating network links.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if enableSpeedLimit {
                    Picker("Maximum speed cap:", selection: $speedLimitKBps) {
                        Text("512 KB/s").tag(512)
                        Text("1 MB/s").tag(1024)
                        Text("2 MB/s").tag(2048)
                        Text("5 MB/s").tag(5120)
                        Text("10 MB/s").tag(10240)
                        Text("25 MB/s").tag(25600)
                        Text("50 MB/s").tag(51200)
                    }
                }
            } header: {
                Text("Bandwidth Throttling")
            }

            Section {
                HStack {
                    Button("Reveal Downloads in Finder") {
                        let defaultFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                        NSWorkspace.shared.open(defaultFolder)
                    }

                    Spacer()

                    Button("Reset All Settings…", role: .destructive) {
                        showingResetAlert = true
                    }
                }
            } header: {
                Text("Diagnostics & Maintenance")
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .alert("Reset All Settings?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset to Defaults", role: .destructive) {
                resetSettingsToDefaults()
            }
        } message: {
            Text("This will restore all connection, update, and performance preferences to their factory defaults.")
        }
    }

    private func resetSettingsToDefaults() {
        let domain = Bundle.main.bundleIdentifier ?? "com.idmac.app"
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }
}
