import Foundation
import AppKit

@MainActor
public final class BrowserIntegrationManager: ObservableObject {
    public static let shared = BrowserIntegrationManager()

    @Published public var isFirefoxInstalled: Bool = false
    @Published public var isChromeInstalled: Bool = false
    @Published public var installationStatusMessage: String?
    @Published public var showInstallGuide: Bool = false

    public let firefoxAppSupportURL: URL
    public let appExtensionsDir: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.appExtensionsDir = appSupport.appendingPathComponent("IDMac/extensions", isDirectory: true)

        let mozillaDir = appSupport.appendingPathComponent("Mozilla", isDirectory: true)
        self.firefoxAppSupportURL = mozillaDir

        refreshBrowserDetection()
    }

    public func refreshBrowserDetection() {
        self.isFirefoxInstalled = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.mozilla.firefox") != nil
        self.isChromeInstalled = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") != nil
    }

    public func installFirefoxExtension() {
        do {
            try FileManager.default.createDirectory(at: appExtensionsDir, withIntermediateDirectories: true)

            // Look for bundled extension or source directory
            var sourceXPI: URL? = Bundle.main.url(forResource: "idmac-firefox", withExtension: "xpi")
            if sourceXPI == nil {
                let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/extensions/idmac-firefox.xpi")
                if FileManager.default.fileExists(atPath: bundled.path) {
                    sourceXPI = bundled
                } else {
                    sourceXPI = findDevExtensionXPI()
                }
            }

            guard let xpi = sourceXPI, FileManager.default.fileExists(atPath: xpi.path) else {
                installationStatusMessage = "Extension package not found. Please build the application."
                return
            }

            let targetXPI = appExtensionsDir.appendingPathComponent("idmac-firefox.xpi")
            try? FileManager.default.removeItem(at: targetXPI)
            try FileManager.default.copyItem(at: xpi, to: targetXPI)

            // Also copy unpacked folder for about:debugging
            let targetUnpacked = appExtensionsDir.appendingPathComponent("firefox", isDirectory: true)
            if let unpackedSrc = findDevExtensionFolder() {
                try? FileManager.default.removeItem(at: targetUnpacked)
                try? FileManager.default.copyItem(at: unpackedSrc, to: targetUnpacked)
            }

            // Launch Firefox with the XPI or open about:debugging
            if let firefoxURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.mozilla.firefox") {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true

                // Open Firefox to about:debugging#/runtime/this-firefox
                if let debugURL = URL(string: "about:debugging#/runtime/this-firefox") {
                    NSWorkspace.shared.open([debugURL], withApplicationAt: firefoxURL, configuration: config) { _, _ in }
                }

                // Reveal extension in Finder so the user can drag or click "Load Temporary Add-on"
                NSWorkspace.shared.selectFile(targetXPI.path, inFileViewerRootedAtPath: appExtensionsDir.path)
            } else {
                // If Firefox is not found by bundle ID, reveal in Finder anyway
                NSWorkspace.shared.selectFile(targetXPI.path, inFileViewerRootedAtPath: appExtensionsDir.path)
            }

            installationStatusMessage = "Firefox extension prepared. In Firefox, click 'Load Temporary Add-on' and choose idmac-firefox.xpi (or manifest.json)."
            showInstallGuide = true
        } catch {
            installationStatusMessage = "Error installing extension: \(error.localizedDescription)"
        }
    }

    private func findDevExtensionXPI() -> URL? {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidate = root.appendingPathComponent("extensions/idmac-firefox.xpi")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    private func findDevExtensionFolder() -> URL? {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidate = root.appendingPathComponent("extensions/firefox", isDirectory: true)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }
}
