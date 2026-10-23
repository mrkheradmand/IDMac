# IDMac versions

All notable changes to the IDMac application will be documented in this file for every change.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## 1.0.5 (build 6) — 2026-10-23

### Added
- None.

### Modified
- **Swift 6 Strict Concurrency Compliance**:
  - Enforced `@MainActor` global actor isolation across SwiftUI view structures (`DownloadTableView`, `MainSplitView`, `SidebarView`, `SegmentInspectorView`, `AddDownloadSheet`, `SettingsView`, and `IDMacApp`).
  - Converted `coordinator` stored property to an isolated computed property (`private var coordinator: DownloadCoordinator { DownloadCoordinator.shared }`) across views, resolving the compiler error where `@MainActor`-isolated static property `shared` was referenced in a synchronous non-isolated context.
  - Resolved GitHub Actions CI release build failure on Xcode 16 / macOS-14 runners.
- Bumped application bundle version to 1.0.5 (build 6).

### Removed
- None.

---

## 1.0.4 (build 5) — 2026-10-23

### Added
- **Automatic GitHub Release Updater (`UpdateManager.swift`)**:
  - Asynchronous background and on-demand checking against `mrkheradmand/IDMac/releases/latest`.
  - Automatic version parsing and semantic version comparison (`isVersionNewer`).
  - Seamless DMG download with direct mounting in Finder for 1-click update installation.
  - Added "Check for Updates…" menu command in the application menu (`CommandGroup(after: .appInfo)`).
- **Native About Window (`AboutWindow.swift`)**:
  - Implemented custom centered `NSPanel` (`AboutWindowController`) with full-resolution app icon, version details, and tagline.
  - Interactive software update status badge (`idle`, `checking`, `upToDate`, `available`, `downloading`, `readyToInstall`, `error`) with direct "Download & Install Update" action.
  - Quick access links to the GitHub repository, releases, and MIT license.
- **Redesigned macOS HIG Settings Window (`SettingsView.swift`)**:
  - Architected a 4-tab native settings interface (`General`, `Acceleration`, `Updates`, `Advanced`) styled with Apple Human Interface Guidelines (`540 × 470 pt`) and `.formStyle(.grouped)`.
  - **General**: Custom download folder picker via `NSOpenPanel`, clipboard monitoring toggle, completion chime toggle, notification banner toggle, and system sleep prevention.
  - **Acceleration**: Default connection streams picker (1–32 streams), max active downloads picker, socket timeout picker, retry attempts picker, and stream buffer size picker.
  - **Updates**: Dedicated software update card with live check trigger, background check toggle, check frequency picker, pre-release/beta toggle, and SHA256 security guarantee.
  - **Advanced**: File pre-allocation mode picker (Sparse vs full `fcntl(F_PREALLOCATE)`), aggregate bandwidth throttling / speed limit controls, Finder temporary folder reveal, and factory reset action.
- **Rule Persistence (`.agents/rules/macos-ui-rules.md`, `.agents/rules/documentation-rules.md`)**:
  - Documented permanent Apple HIG rules for macOS Settings, About panels, modal sheets, and window tabbing.
  - Established permanent rule requiring dual-tier documentation maintenance (`/README.md` for users, `/developer_docs/README.md` for developers) on every code change.
- **Licensing & Copyright**:
  - Added official MIT License file (`LICENSE`) with copyright notice `Copyright (c) 2026 J Kheradmand`.
  - Configured `NSHumanReadableCopyright` in `Resources/Info.plist` and `scripts/build_app.sh`.
  - Added copyright notice in `AboutWindow.swift` view footer.
  - Added dedicated License & Copyright sections to both `README.md` and `developer_docs/README.md`.
- **Seamless Toolbar Search Field (`NativeSearchField.swift`)**:
  - Implemented custom `UnborderedSearchField` suppressing the macOS blue focus ring border.
  - Added global click-to-unfocus monitor dismissing the search box whenever clicking anywhere else in the application.
- **Dual-Tier Documentation Framework**:
  - Created user-facing non-technical manual in `README.md` focusing on features, installation, Gatekeeper guidance, and usage.
  - Created developer systems architecture guide in `developer_docs/README.md` covering Swift concurrency, POSIX I/O, SwiftData persistence, AppKit bridges, and build pipelines.
  - Created practical step-by-step GitHub release guide in `developer_docs/HOW_TO_RELEASE.md`.

### Modified
- Replaced standard `.searchable` with `NativeSearchField` in the window toolbar for borderless focus styling and click-outside dismissal.
- Reordered navigation sidebar layout: positioned the **Status** section at the top and the **Categories** section below it.
- Added **All Downloads** item to the top of the **Status** section as the primary filter.
- Removed **All Downloads** from the **Categories** section, leaving pure file-type groupings (Compressed, Documents, Music, Programs, Video, Other).
- Added contextual dynamic empty-state messaging in `MainSplitView.swift` based on the active status or category filter.
- Connected custom `AboutWindowController` to the application menu (`CommandGroup(replacing: .appInfo)`), replacing the standard generic alert.
- Updated `AddDownloadSheet.swift` to automatically pre-populate the user's custom default download folder and connection stream count from settings.
- Initialized `UpdateManager.shared.startBackgroundCheck()` inside `AppDelegate.applicationDidFinishLaunching`.
- Enhanced `scripts/build_app.sh` to dynamically extract application version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`) from `Resources/Info.plist`.
- Bumped application bundle version to 1.0.4 (build 5).
- Relocated and consolidated `Architectural-Comparison.md` permanently into `developer_docs/Architectural-Comparison.md`.

### Removed
- Removed legacy unorganized single-tab Settings form.

---

## 1.0.3 (build 4) — 2026-10-23

### Added
- Added `AppDelegate` in `IDMacApp.swift` with `NSWindow.allowsAutomaticWindowTabbing = false` and menu item scrubber to disallow window tabbing.
- Created `developer_docs/RELEASE_PROCESS_INSTRUCTIONS.md` containing full step-by-step release operations.
- Created complete automated GitHub release infrastructure:
  - `scripts/build_dmg.sh`: Native macOS APFS/UDZO disk image builder with `/Applications` symlink and SHA256 checksum verification.
  - `scripts/release_metadata.py`: Tri-source validator (`Info.plist`, `versions.md`, Git tag) and smart release note aggregator.
  - `scripts/publish_release.py`: Two-phase atomic GitHub release publisher (draft creation $\rightarrow$ remote digest verification $\rightarrow$ public release).
  - `.github/workflows/release.yml`: Automated CI/CD release workflow triggered on `v*` tag pushes.
  - `scripts/make_release.sh`: Local release helper for version bumping, building, tagging, and publishing.
  - `Resources/Install Notes.txt`: User guide explaining Gatekeeper bypass on macOS.
- Set default window dimensions to `1060 × 640` in `IDMacApp.swift` to ensure all 8 columns fit without clipping on initial launch.
- Constrained sidebar column width (`min: 180, ideal: 200, max: 240`) in `MainSplitView.swift` to maximize available space for the main downloads table.
- Added `.scrollIndicators(.never, axes: .horizontal)` on `DownloadTableView` to eliminate the horizontal scrollbar indicator.
- Created `Architectural-Comparison.md` documenting deep systems comparison between IDMac and ELMedia Player (Lola Player).
- Established `versions.md` as the persistent versioning log for tracking all additions, modifications, and removals across releases.

### Modified
- Disabled window tabbing mode (`window.tabbingMode = .disallowed`) across all application windows.
- Updated `.gitignore` to permanently ignore `.DS_Store`, `**/.DS_Store`, and `dist/`.
- Rebalanced all 8 column widths in `DownloadTableView.swift` (File Name, Size, Status, Progress, Speed, Time Left, Resume, Date Added) to an aggregate ideal width of ~810 pt so all columns remain visible simultaneously.
- Optically scaled the active squircle app icon from 824px to 876px (+6.3%) to eliminate perceived shrinkage in the macOS Dock alongside high-luminance system icons.

### Removed
- Removed "Show Tab Bar" and "Show All Tabs" menu items from the View menu.
- Untracked all `.DS_Store` files from Git tracking, cache, and monitoring.
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

