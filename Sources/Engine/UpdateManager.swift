import Foundation
import AppKit
import SwiftUI

public struct AppUpdate: Equatable, Sendable {
    public let version: String
    public let title: String
    public let releaseURL: URL
    public let dmgURL: URL?
    public let body: String
    public let publishedAt: String

    public init(version: String, title: String, releaseURL: URL, dmgURL: URL?, body: String, publishedAt: String) {
        self.version = version
        self.title = title
        self.releaseURL = releaseURL
        self.dmgURL = dmgURL
        self.body = body
        self.publishedAt = publishedAt
    }
}

public enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(AppUpdate)
    case downloading(progress: Double)
    case readyToInstall(dmgURL: URL)
    case error(String)
}

@MainActor
public final class UpdateManager: ObservableObject {
    public static let shared = UpdateManager()

    @Published public var state: UpdateState = .idle
    @Published public var lastChecked: Date?

    @AppStorage("automaticallyCheckForUpdates") public var automaticallyCheckForUpdates: Bool = true
    @AppStorage("lastUpdateCheckTime") private var lastUpdateCheckTime: Double = 0

    public let repoSlug = "mrkheradmand/IDMac"
    private var downloadTask: URLSessionDownloadTask?

    public init() {
        if lastUpdateCheckTime > 0 {
            lastChecked = Date(timeIntervalSince1970: lastUpdateCheckTime)
        }
    }

    public var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.11"
    }

    public var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "12"
    }

    public func startBackgroundCheck() {
        guard automaticallyCheckForUpdates else { return }

        // Check once per 24 hours if already checked recently
        let now = Date().timeIntervalSince1970
        if now - lastUpdateCheckTime > 86400 {
            Task {
                await checkForUpdates(manual: false)
            }
        }
    }

    public func checkForUpdates(manual: Bool = true) async {
        guard state != .checking else { return }

        state = .checking
        let endpoint = URL(string: "https://api.github.com/repos/\(repoSlug)/releases/latest")!

        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("IDMac/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                state = .error("Invalid server response.")
                return
            }

            if httpResponse.statusCode == 404 {
                // No published releases on repository yet
                self.recordCheckTime()
                self.state = .upToDate
                return
            }

            guard httpResponse.statusCode == 200 else {
                state = .error("GitHub API returned status \(httpResponse.statusCode).")
                return
            }

            let release = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)

            guard !release.draft && !release.prerelease else {
                self.recordCheckTime()
                self.state = .upToDate
                return
            }

            let tagClean = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name

            if isVersionNewer(latest: tagClean, current: currentVersion) {
                // Find DMG asset
                let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") })
                let dmgURL = dmgAsset.flatMap { URL(string: $0.browser_download_url) }

                let update = AppUpdate(
                    version: tagClean,
                    title: release.name ?? "IDMac \(tagClean)",
                    releaseURL: URL(string: release.html_url) ?? URL(string: "https://github.com/\(repoSlug)/releases")!,
                    dmgURL: dmgURL,
                    body: release.body ?? "",
                    publishedAt: release.published_at ?? ""
                )

                self.recordCheckTime()
                self.state = .available(update)
            } else {
                self.recordCheckTime()
                self.state = .upToDate
            }
        } catch {
            if manual {
                self.state = .error("Check failed: \(error.localizedDescription)")
            } else {
                self.state = .idle
            }
        }
    }

    public func downloadAndApplyUpdate(update: AppUpdate) {
        guard let dmgURL = update.dmgURL else {
            // Fallback to opening GitHub release page
            NSWorkspace.shared.open(update.releaseURL)
            return
        }

        state = .downloading(progress: 0.0)

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        Task {
            do {
                let (tempURL, response) = try await session.download(from: dmgURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    state = .error("Failed to download update file.")
                    return
                }

                // Move to Downloads or Caches directory
                let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let destination = downloadsDir.appendingPathComponent("IDMac-\(update.version)-macOS-arm64.dmg")

                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: tempURL, to: destination)

                self.state = .readyToInstall(dmgURL: destination)

                // Open the downloaded DMG disk image for the user
                NSWorkspace.shared.open(destination)
            } catch {
                self.state = .error("Download failed: \(error.localizedDescription)")
            }
        }
    }

    private func recordCheckTime() {
        let now = Date()
        self.lastChecked = now
        self.lastUpdateCheckTime = now.timeIntervalSince1970
    }

    private func isVersionNewer(latest: String, current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(latestParts.count, currentParts.count) {
            let l = i < latestParts.count ? latestParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }

    // MARK: - API Decodable Models
    private struct GitHubReleaseResponse: Decodable {
        let tag_name: String
        let name: String?
        let draft: Bool
        let prerelease: Bool
        let html_url: String
        let body: String?
        let published_at: String?
        let assets: [GitHubAssetResponse]
    }

    private struct GitHubAssetResponse: Decodable {
        let name: String
        let browser_download_url: String
        let size: Int
    }
}
