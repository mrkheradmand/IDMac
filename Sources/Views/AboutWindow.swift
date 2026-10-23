import SwiftUI
import AppKit

public final class AboutWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = AboutWindowController()

    public init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.title = "About IDMac"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true

        super.init(window: panel)
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: AboutView())
        panel.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

public struct AboutView: View {
    @ObservedObject private var updateManager = UpdateManager.shared
    private let repoURL = URL(string: "https://github.com/mrkheradmand/IDMac")!

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // App Icon
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            } else {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.accentColor)
            }

            // App Titles
            VStack(spacing: 4) {
                Text("IDMac")
                    .font(.system(size: 24, weight: .bold))

                Text("Native Segmented Download Accelerator")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Text("Version \(updateManager.currentVersion) (Build \(updateManager.currentBuild))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.horizontal, 20)

            // Update Status Card
            VStack(spacing: 10) {
                switch updateManager.state {
                case .idle:
                    HStack(spacing: 8) {
                        Text("Keep IDMac updated with the latest improvements.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Check for Updates") {
                            Task {
                                await updateManager.checkForUpdates(manual: true)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                case .checking:
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking GitHub for updates…")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                case .upToDate:
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("IDMac is up to date.")
                                .font(.system(size: 12, weight: .medium))
                            if let last = updateManager.lastChecked {
                                Text("Last checked: \(last.formatted(date: .omitted, time: .shortened))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button("Check Again") {
                            Task {
                                await updateManager.checkForUpdates(manual: true)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                case .available(let update):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
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

                            Link("View Release Notes", destination: update.releaseURL)
                                .font(.system(size: 11))
                        }
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(8)

                case .downloading(let progress):
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Downloading update…")
                                .font(.system(size: 12))
                            Spacer()
                            if progress > 0 {
                                Text("\(Int(progress * 100))%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            } else {
                                ProgressView()
                                    .controlSize(.small)
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
                        Text("Update disk image opened in Finder.")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }

                case .error(let message):
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        Spacer()
                        Button("Retry") {
                            Task {
                                await updateManager.checkForUpdates(manual: true)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Checkbox toggle
                Toggle("Automatically check for updates", isOn: $updateManager.automaticallyCheckForUpdates)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Footer Links & Copyright
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    Link("GitHub Repository", destination: repoURL)
                    Text("•").foregroundColor(.secondary)
                    Link("Releases", destination: repoURL.appendingPathComponent("releases"))
                    Text("•").foregroundColor(.secondary)
                    Link("MIT License", destination: repoURL.appendingPathComponent("blob/main/LICENSE"))
                }
                .font(.system(size: 11))

                Text("Built natively with Swift, SwiftUI, and SwiftData for macOS.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)
        }
        .frame(width: 480, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
