import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@MainActor
public struct AddDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var urlString = ""
    @State private var selectedFolderURL: URL
    @State private var connectionCount: Int = 8
    @State private var isProbing = false
    @State private var detectedFilename = ""
    @State private var detectedSize: Int64 = 0
    @State private var detectedResume = false

    private var coordinator: DownloadCoordinator {
        DownloadCoordinator.shared
    }

    public init() {
        let savedPath = UserDefaults.standard.string(forKey: "defaultDownloadDirectory")
        let defaultFolder: URL
        if let savedPath = savedPath, !savedPath.isEmpty, FileManager.default.fileExists(atPath: savedPath) {
            defaultFolder = URL(fileURLWithPath: savedPath)
        } else {
            defaultFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        }
        let savedConnections = UserDefaults.standard.integer(forKey: "defaultConnections")
        self._selectedFolderURL = State(initialValue: defaultFolder)
        self._connectionCount = State(initialValue: savedConnections > 0 ? savedConnections : 8)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enter New Address to Download")
                        .font(.headline)
                    Text("Paste any HTTP/HTTPS URL or file link")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // URL input
            VStack(alignment: .leading, spacing: 6) {
                Text("Address (URL):")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    TextField("https://example.com/file.zip", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            probeURL()
                        }

                    Button("Paste") {
                        if let clip = NSPasteboard.general.string(forType: .string) {
                            urlString = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                            probeURL()
                        }
                    }
                }
            }

            // Probe results summary
            if isProbing {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Connecting to server and inspecting stream headers...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            } else if !detectedFilename.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Detected File:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(detectedFilename)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 16) {
                        Text("Size: \(FormatUtils.formatBytes(detectedSize))")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Multipart Resume: \(detectedResume ? "Supported" : "Unsupported")")
                            .font(.caption)
                            .foregroundColor(detectedResume ? .green : .orange)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }

            // Save Folder Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("Save To Directory:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.yellow)
                    Text(selectedFolderURL.path)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Browse...") {
                        selectDestinationFolder()
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }

            // Connection Streams
            HStack {
                Text("Connection Streams:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Picker("", selection: $connectionCount) {
                    Text("1 stream (Single)").tag(1)
                    Text("4 streams").tag(4)
                    Text("8 streams (Default)").tag(8)
                    Text("16 streams (Maximum)").tag(16)
                    Text("32 streams (Extreme)").tag(32)
                }
                .frame(width: 180)
            }

            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Download Later") {
                    Task {
                        await coordinator.addDownload(
                            urlString: urlString,
                            destinationFolder: selectedFolderURL,
                            connectionCount: connectionCount,
                            modelContext: modelContext,
                            startImmediately: false
                        )
                        dismiss()
                    }
                }
                .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Start Download") {
                    Task {
                        await coordinator.addDownload(
                            urlString: urlString,
                            destinationFolder: selectedFolderURL,
                            connectionCount: connectionCount,
                            modelContext: modelContext,
                            startImmediately: true
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear {
            checkClipboard()
        }
    }

    private func checkClipboard() {
        if let clip = NSPasteboard.general.string(forType: .string) {
            let trimmed = clip.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                urlString = trimmed
                probeURL()
            }
        }
    }

    private func probeURL() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        isProbing = true
        Task {
            if let probe = try? await DownloadEngine.probe(url: url) {
                await MainActor.run {
                    detectedFilename = probe.filename
                    detectedSize = probe.totalSize
                    detectedResume = probe.supportsResume
                    isProbing = false
                }
            } else {
                await MainActor.run {
                    detectedFilename = url.lastPathComponent
                    detectedSize = 0
                    detectedResume = false
                    isProbing = false
                }
            }
        }
    }

    private func selectDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let url = panel.url {
            selectedFolderURL = url
        }
    }
}
