import Foundation

public enum DownloadStatus: String, Codable, CaseIterable, Sendable {
    case queued = "Queued"
    case connecting = "Connecting"
    case downloading = "Downloading"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"

    public var iconName: String {
        switch self {
        case .queued: return "clock"
        case .connecting: return "network"
        case .downloading: return "arrow.down.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        }
    }
}

public enum DownloadCategory: String, Codable, CaseIterable, Sendable {
    case all = "All Downloads"
    case compressed = "Compressed"
    case documents = "Documents"
    case music = "Music"
    case programs = "Programs"
    case video = "Video"
    case other = "Other"

    public var iconName: String {
        switch self {
        case .all: return "tray.full.fill"
        case .compressed: return "archivebox.fill"
        case .documents: return "doc.text.fill"
        case .music: return "music.note"
        case .programs: return "app.fill"
        case .video: return "film.fill"
        case .other: return "folder.fill"
        }
    }

    public static func inferCategory(fromFilename filename: String) -> DownloadCategory {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz":
            return .compressed
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "epub":
            return .documents
        case "mp3", "wav", "flac", "aac", "m4a", "ogg", "wma":
            return .music
        case "dmg", "pkg", "app", "iso", "exe", "msi", "bin", "deb", "rpm":
            return .programs
        case "mp4", "mkv", "mov", "avi", "wmv", "flv", "webm", "m4v":
            return .video
        default:
            return .other
        }
    }
}

public enum FormatUtils {
    public static func formatBytes(_ bytes: Int64) -> String {
        if bytes < 0 { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    public static func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec <= 0 { return "---" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: Int64(bytesPerSec)))/s"
    }

    public static func formatETA(remainingBytes: Int64, bytesPerSec: Double) -> String {
        guard bytesPerSec > 1024, remainingBytes > 0 else { return "---" }
        let seconds = Double(remainingBytes) / bytesPerSec
        if seconds > 86400 { return "> 1 day" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? "---"
    }
}
