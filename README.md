# IDMac: Native Segmented Download Manager for macOS

A high-performance, native macOS download accelerator built with **SwiftUI**, **SwiftData**, and **Swift Concurrency**, featuring the classic download manager 3-pane layout, 8-part concurrent connection acceleration, pause/resume capability, and real-time segment monitoring.

---

## Features

- **Multi-Part Accelerated Downloading**: Automatically probes HTTP/HTTPS server capabilities (`Accept-Ranges: bytes`) and splits file downloads across **8 concurrent connection streams** (configurable up to 32 streams).
- **Crash Recovery & Pause/Resume**: Safely pauses downloads and resumes without redownloading finished bytes.
- **Classic 3-Pane Desktop Layout**:
  - **Toolbar**: Add URL, Resume, Pause, Stop All, Delete, and Search.
  - **Category Sidebar**: Status filters (*Downloading*, *Completed*, *Paused*, *Queued*, *Failed*) and file type groups (*Compressed*, *Documents*, *Music*, *Programs*, *Video*, *Other*).
  - **Main Table**: High-performance table displaying filename, size, progress, transfer rate (speed), ETA, resume status, and date added.
  - **Segment Inspector**: Real-time visual monitoring of each concurrent thread's progress and byte offset.
- **Smart Clipboard Detection**: Automatically detects URLs copied to the macOS clipboard when opening the "Add URL" dialog.
- **Persistent Storage**: Backed by **SwiftData** for fast, reliable local state management.

---

## Project Structure

```
IDMac/
├── IDMac.xcodeproj                 # Native Xcode Project
├── Package.swift                   # Swift Package Manager manifest
├── project.yml                     # XcodeGen configuration
├── Sources/
│   ├── App/
│   │   ├── IDMacApp.swift          # Main SwiftUI App & ModelContainer setup
│   │   └── ContentView.swift       # Root Window container
│   ├── Models/
│   │   ├── DownloadItem.swift      # SwiftData Download model
│   │   ├── DownloadSegment.swift   # Individual chunk stream state
│   │   └── DownloadTypes.swift     # Categories, statuses, formatters
│   ├── Engine/
│   │   ├── DownloadEngine.swift    # Multi-part chunk scheduler & probe
│   │   ├── SegmentWorker.swift     # HTTP Range byte streaming worker
│   │   ├── FileStorageManager.swift# Sparse pre-allocated offset writer
│   │   └── DownloadCoordinator.swift# MainActor task coordinator
│   └── Views/
│       ├── MainSplitView.swift     # NavigationSplitView & Toolbar
│       ├── SidebarView.swift       # Category & status navigation
│       ├── DownloadTableView.swift # Interactive data table & context menus
│       ├── SegmentInspectorView.swift# Multi-thread visual inspector
│       ├── AddDownloadSheet.swift  # URL entry & clipboard detection sheet
│       ├── SettingsView.swift      # Preferences & concurrency limits
│       └── Components/
│           ├── ClassicProgressBar.swift
│           └── StatusBadge.swift
└── Resources/
    ├── Info.plist                  # macOS permissions & ATS configuration
    └── Assets.xcassets             # App icon set
```

---

## How to Open and Run

### Option 1: Xcode
Double-click [`IDMac.xcodeproj`](./IDMac.xcodeproj) to open the project in Xcode, then select target **IDMac (macOS)** and click **Run** (`⌘R`).

### Option 2: Terminal / Swift PM
To build and run from the command line:

```bash
swift run \
  -Xswiftc -load-plugin-library -Xswiftc /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftDataMacros.dylib \
  -Xswiftc -load-plugin-library -Xswiftc /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib
```
