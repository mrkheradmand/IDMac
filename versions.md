# IDMac versions

All notable changes to the IDMac application will be documented in this file for every change.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## 1.0.11 (build 12) — 2026-10-23

### Added
- **Duplicate Download Detection & Conflict Dialog (`DownloadCoordinator.swift`)**:
  - Automatically intercepts duplicate downloads when adding files that already exist in the IDMac download list (by URL, filename, or destination path) or in the destination folder on disk.
  - Activates and presents a native macOS dialog detailing current file status (Completed, Currently Downloading with progress percentage, Paused, or existing on disk).
  - Offers intuitive resolution actions:
    - **Auto-Rename (Keep Both)** (Default): Automatically appends an incremental counter (e.g., `file (1).ext`) to preserve both the existing file and the new download without conflict.
    - **Overwrite**: Cleanly resets/replaces any existing entry, deletes partial/existing file, and starts download fresh.
    - **Cancel**: Aborts duplicate download request without modifying existing files or tasks.
    - **Reveal in Finder**: One-click action to highlight and reveal the existing completed file in macOS Finder.
- **Browser File Name Forwarding (`LocalServer.swift`)**:
  - Forwarded custom filename from Firefox Companion `POST /add` to ensure accurate duplicate matching before probing headers.

### Modified
- **Add Download Sheet Flow (`AddDownloadSheet.swift`)**:
  - Preserves user input if a duplicate prompt is cancelled, allowing destination or URL modification.
- Bumped application bundle version to 1.0.11 (build 12).

### Removed
- Eliminated silent file overwriting and duplicate race conditions when downloading the same file multiple times.

---

## 1.0.10 (build 11) — 2026-10-23

### Added
- None.

### Modified
- **Chrome Extension Roadmap Sheet (`SettingsView.swift`)**:
  - Embedded Manifest V3 technical architecture and implementation roadmap directly within the in-app modal sheet.
- Bumped application bundle version to 1.0.10 (build 11).

### Removed
- Removed all file references and links to internal developer documentation from application windows (`ChromePlanSheet`) and project documentation.

---

## 1.0.9 (build 10) — 2026-10-23

### Added
- **Listener Status & Error Diagnostics (`SettingsView.swift`)**:
  - Added visual error diagnostics badge displaying specific socket error details if the local server fails to bind.
  - Added "Restart" action button alongside the active status badge in Settings -> Browsers.
  - Automatically verifies and activates the local listener when opening the Browsers settings tab (`.onAppear`).

### Modified
- **POSIX BSD Loopback Socket Engine (`LocalServer.swift`)**:
  - Replaced `Network.framework` (`NWListener`) with a rock-solid, entitlement-free POSIX BSD loopback socket (`AF_INET`, `SOCK_STREAM`, `SO_REUSEADDR`, `bind("127.0.0.1", 23485)`).
  - Fixed an issue where clicking "Start Listener" did nothing due to `NWListener` throwing `POSIXErrorCode(rawValue: 22): Invalid argument` in ad-hoc binaries on macOS Sonoma/Sequoia.
  - Added clean socket cleanup and restart capability without deadlocking `isRunning` state.
- **Companion Extension Version Synchronization**:
  - Bumped Firefox extension manifest and popup to v1.0.9, synchronized with app release bundle.
- Bumped application bundle version to 1.0.9 (build 10).

### Removed
- Eliminated silent `NWListener` initialization failures and port-binding deadlocks in `LocalServer`.

---

## 1.0.8 (build 9) — 2026-10-23

### Added
- None.

### Modified
- **Menu Bar Icon Refinement (`MenuBarManager.swift`)**:
  - Increased system status bar template icon size by 10% (`pointSize: 15.5` with proportional 1.10x scale) for improved visual prominence and legibility in the macOS menu bar.
- Bumped application bundle version to 1.0.8 (build 9).

### Removed
- None.

---

## 1.0.7 (build 8) — 2026-10-23

### Added
- **Direct 1-Click Menu Bar App Activation (`MenuBarManager.swift`)**:
  - Left-clicking (primary click) the macOS menu bar icon instantly opens and focuses IDMac (restoring the application from background, re-displaying the Dock icon, and bringing the main window frontmost).
  - Right-clicking (or Control-clicking) reveals the quick action dropdown menu with real-time download status, "Add Download URL…", "Resume All", "Pause All", "Settings…", "Check for Updates…", and "Quit IDMac".
- **Mozilla Firefox Browser Extension (`extensions/firefox/`)**:
  - Created complete WebExtensions companion extension for Mozilla Firefox.
  - Automatic download interception via `browser.downloads.onCreated`, pausing native single-stream browser downloads and routing them to IDMac for multi-part acceleration.
  - Graceful fallback: If IDMac is offline or closed, Firefox seamlessly downloads files natively without user interruption.
  - Right-click context menus: "Download with IDMac" and "Download Media with IDMac".
  - macOS HIG popup with live connection status badge (Connected / Offline), capture toggle switch, and 1-click app launcher.
  - Packaged both `.xpi` and unpacked format inside the application bundle (`Contents/Resources/extensions/`).
- **Browsers Settings Tab & 1-Click Extension Installer (`SettingsView.swift`)**:
  - Added dedicated **Browsers** tab in Settings with:
    - Mozilla Firefox companion installer: Copies extension package to `~/Library/Application Support/IDMac/extensions/`, launches Firefox to `about:debugging#/runtime/this-firefox`, reveals the extension file in Finder, and presents an interactive 3-step installation guide.
    - Google Chrome & Chromium roadmap card with in-app architectural blueprint viewer.
    - Live Local Bridge connection status monitor.
- **Local Bridge Server (`LocalServer.swift`)**:
  - Lightweight localhost loopback HTTP server (`http://127.0.0.1:23485`) built on Apple's native `Network.framework` (`NWListener`).
  - Endpoints: `GET /health` (heartbeat & version check) and `POST /add` (queued download task ingestion with CORS support).
- **Custom URL Scheme (`idmac://`)**:
  - Registered `idmac://add?url=...` in `Info.plist` and `IDMacApp.swift` via `.onOpenURL` for instant browser and CLI link invocation.
- **Chrome Extension Architecture Plan**:
  - Formulated full Manifest V3 architectural plan with sequence diagrams, service worker lifecycle, and declarativeNetRequest integration.

### Modified
- **Segment Size & Progress Calculation Fix**:
  - Resolved the bug where connection segments displayed as "66 KB / 66 KB" regardless of the true file size (e.g. 8 × 66 KB on a 12.7 MB file).
  - Pre-allocated segment models in SwiftData with exact byte ranges (`startByte` to `endByte`) prior to launching worker task groups instead of dynamically instantiating segments from the first 64 KB memory chunk.
  - Added self-healing display logic in `SegmentInspectorView.swift` to automatically repair and accurately format any legacy completed downloads stored in SwiftData.
- Bumped application bundle version to 1.0.7 (build 8).

### Removed
- None.

---

## 1.0.6 (build 7) — 2026-10-23

### Added
- **macOS Menu Bar Status Item (`MenuBarManager.swift`)**:
  - Implemented persistent system status item (`NSStatusItem`) with template icon (`arrow.down.circle`) adapting dynamically to macOS Light and Dark appearance.
  - Real-time download progress summary header directly inside the menu bar dropdown ("IDMac: Downloading (X) • Y MB/s" or "IDMac: Idle").
  - Quick action controls: "Show IDMac", "Add Download URL…", "Resume All", "Pause All", "Settings…", "Check for Updates…", and "Quit IDMac".
  - Dynamic delegate menu population updating download statistics each time the menu bar dropdown is displayed.
- **Window Close Interception & Dock Hiding**:
  - Seamless background persistence: Closing the main window (via close button or Cmd+W) hides the window while IDMac continues running in the menu bar.
  - Dynamic Dock icon suppression: Option to switch application activation policy to `.accessory` when the main window is closed, completely removing IDMac from the macOS Dock and Cmd+Tab application switcher.
  - Instant window restoration: Clicking "Show IDMac", triggering "Add Download URL…", or reopening IDMac from Launchpad/Spotlight restores `.regular` activation policy, re-displays the Dock icon, and brings the main window forward.
- **Launch at System Startup (`LaunchAtLoginManager.swift`)**:
  - Modern macOS 13+ native `ServiceManagement` (`SMAppService.mainApp`) integration to register/unregister IDMac for launch at login.
  - No legacy helper bundles or elevated privileges required.
- **Menu Bar & Startup Settings Section (`SettingsView.swift`)**:
  - Added dedicated configuration controls in the "General" settings tab:
    - "Launch IDMac at system startup" toggle (`SMAppService.mainApp`).
    - "Show status icon in menu bar" toggle (`showMenuBarIcon`).
    - "Keep IDMac running in menu bar when window is closed" toggle (`keepRunningInMenuBar`).
    - "Hide Dock icon when window is closed" toggle (`hideDockIconWhenClosed`).
- **Download Coordinator Global Controls (`DownloadCoordinator.swift`)**:
  - Added `resumeAllDownloads()`, `pauseAllDownloads()`, and `getActiveDownloadStats()` helpers for menu bar and global shortcut triggers.

### Modified
- Connected `DownloadCoordinator` model context lifecycle to `MainSplitView.onAppear` to guarantee swift data persistence on startup.
- Connected application main menu "Downloads -> Resume All" (Cmd+Shift+R) and "Downloads -> Stop All" (Cmd+Shift+S) to coordinator methods.
- Bumped application bundle version to 1.0.6 (build 7).

### Removed
- None.

---

## 1.0.5 (build 6) — 2026-10-23

### Added
- None.

### Modified
- **Swift 6 Strict Concurrency Compliance**:
  - Enforced `@MainActor` global actor isolation across SwiftUI view structures (`DownloadTableView`, `MainSplitView`, `SidebarView`, `SegmentInspectorView`, `AddDownloadSheet`, `SettingsView`, and `IDMacApp`).
  - Converted `coordinator` stored property to an isolated computed property (`private var coordinator: DownloadCoordinator { DownloadCoordinator.shared }`) across views, resolving the compiler error where `@MainActor`-isolated static property `shared` was referenced in a synchronous non-isolated context.
  - Eliminated captured `weak self` variables from concurrently executing closures in `DownloadCoordinator.swift` by dispatching directly to `@MainActor` singleton (`DownloadCoordinator.shared`), resolving `reference to captured var 'self' in concurrently-executing code` errors.
  - Explicitly pinned `-swift-version 5` in `scripts/build_app.sh` to guarantee identical compiler language mode semantics across all local and CI toolchains.
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
  - Established permanent rule requiring comprehensive documentation maintenance on every code change.
- **Licensing & Copyright**:
  - Added official MIT License file (`LICENSE`) with copyright notice `Copyright (c) 2026 J Kheradmand`.
  - Configured `NSHumanReadableCopyright` in `Resources/Info.plist` and `scripts/build_app.sh`.
  - Added copyright notice in `AboutWindow.swift` view footer.
  - Added dedicated License & Copyright sections to `README.md`.
- **Seamless Toolbar Search Field (`NativeSearchField.swift`)**:
  - Implemented custom `UnborderedSearchField` suppressing the macOS blue focus ring border.
  - Added global click-to-unfocus monitor dismissing the search box whenever clicking anywhere else in the application.
- **Documentation Framework**:
  - Created user-facing non-technical manual in `README.md` focusing on features, installation, Gatekeeper guidance, and usage.
  - Created developer systems architecture guide covering Swift concurrency, POSIX I/O, SwiftData persistence, AppKit bridges, and build pipelines.
  - Created practical step-by-step GitHub release guide.

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
- Relocated and consolidated architectural comparison documentation.

### Removed
- Removed legacy unorganized single-tab Settings form.

---

## 1.0.3 (build 4) — 2026-10-23

### Added
- Added `AppDelegate` in `IDMacApp.swift` with `NSWindow.allowsAutomaticWindowTabbing = false` and menu item scrubber to disallow window tabbing.
- Created release operations documentation containing full step-by-step procedures.
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
- Documented full icon asset specifications.

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

