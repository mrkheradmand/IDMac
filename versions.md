# IDMac versions

All notable changes to the IDMac application will be documented in this file for every change.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## 1.0.3 (build 4) — 2026-10-23

### Added
- Set default window dimensions to `1060 × 640` in `IDMacApp.swift` to ensure all 8 columns fit without clipping on initial launch.
- Constrained sidebar column width (`min: 180, ideal: 200, max: 240`) in `MainSplitView.swift` to maximize available space for the main downloads table.
- Added `.scrollIndicators(.never, axes: .horizontal)` on `DownloadTableView` to eliminate the horizontal scrollbar indicator.
- Created `Architectural-Comparison.md` documenting deep systems comparison between IDMac and ELMedia Player (Lola Player).
- Established `versions.md` as the persistent versioning log for tracking all additions, modifications, and removals across releases.

### Modified
- Rebalanced all 8 column widths in `DownloadTableView.swift` (File Name, Size, Status, Progress, Speed, Time Left, Resume, Date Added) to an aggregate ideal width of ~810 pt so all columns remain visible simultaneously.
- Optically scaled the active squircle app icon from 824px to 876px (+6.3%) to eliminate perceived shrinkage in the macOS Dock alongside high-luminance system icons.

### Removed
- Removed the unwanted horizontal scrollbar thumb and corner junction artifact that previously appeared in the bottom-right corner of the table on launch.

---

## 1.0.2 (build 3) — 2026-10-23

### Added
- Added `Resources/AppIcon_EightPartRing_Clean.png` with 100% alpha transparency outside the squircle and a subtle native macOS drop shadow.
- Created persistent rule in `.agents/rules/app-icon-rules.md` requiring that all future macOS app icon assets use 100% transparent backgrounds outside the squircle.
- Documented full icon asset specifications in `developer_docs/app_icon_guidelines.md`.

### Modified
- Switched active application icon to the Eight-Part Ring concept (`05-eight-part-ring.png`), featuring eight cyan and mint stream arcs surrounding a downward accelerator arrow.
- Re-rasterized all standard macOS asset catalog resolutions ($16\times16$ through $1024\times1024$ Retina) into `Resources/Assets.xcassets/AppIcon.appiconset/`.
- Recompiled `Resources/AppIcon.icns` and `Assets.car` and refreshed LaunchServices cache.

### Removed
- Removed outer gray canvas borders, studio floors, and opaque box margins from the app icon assets.
- Untracked `Resources/IconConcepts/` from Git caching and staging via `.gitignore`.

---

## 1.0.1 (build 2) — 2026-10-23

### Added
- Created native packaging and bundling shell script `scripts/build_app.sh` supporting `-c` (configuration), `-r` (immediate launch), and `--clean`.
- Integrated automated asset compilation via `actool` and ad-hoc code signing (`codesign`) for local execution.
- Added `CFBundleIconFile` key to `Resources/Info.plist` linking to `AppIcon`.

### Modified
- Enhanced `scripts/build_app.sh` to automatically synchronize standalone `AppIcon.icns` into `Contents/Resources/`.

### Removed
- None.

---

## 1.0.0 (build 1) — 2026-10-23

### Added
- Initial release of IDMac, a native segmented download accelerator for macOS built with SwiftUI and SwiftData.
- **Concurrent Download Engine**: Automatic HTTP `HEAD` probing for `Accept-Ranges: bytes` support and dynamic splitting into 8 concurrent chunk streams.
- **Segment Worker**: Range-based HTTP stream worker using `URLSession` data streaming.
- **Sparse File Storage**: POSIX `fcntl(F_PREALLOCATE)` pre-allocation and direct offset writer (`pwrite`) preventing memory bottlenecks.
- **Crash Recovery & Resume**: Persistent state management tracking downloaded byte ranges per segment for pause/resume without data re-downloading.
- **Classic 3-Pane UI**: Split view with Category and Status sidebar, interactive multi-column data table, toolbar controls, and real-time thread segment visualizer.
- **Smart Clipboard Detection**: Automatic URL detection from system pasteboard on opening the "Add URL" dialog.
- **Persistence Layer**: SwiftData `@Model` classes (`DownloadItem`, `DownloadSegment`) and `DownloadCoordinator`.
- Initial project configuration with `Package.swift` and `project.yml` (XcodeGen).

### Modified
- None.

### Removed
- None.

