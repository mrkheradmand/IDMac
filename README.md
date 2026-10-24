# IDMac ⚡

### Native Multi-Stream Download Accelerator for macOS

IDMac is a high-speed, modern download manager designed exclusively for macOS. Built from scratch with Apple's native **SwiftUI** and **SwiftData** frameworks, IDMac delivers blazing-fast multi-part download acceleration, resilient crash recovery, and a beautiful interface that feels right at home on your Mac.

No Electron. No web wrappers. No bloat. Just pure, lightning-fast native macOS performance.

---

## ✨ Features You'll Love

* 🚀 **Blazing-Fast Acceleration**: Automatically splits large downloads into multiple concurrent connection streams (up to 32 parallel streams) to saturate your bandwidth and download files up to 5x faster.
* ⏸️ **Pause & Resume Anytime**: Never lose download progress again. Safely pause downloads, withstand sudden network disconnects, or resume interrupted downloads without redownloading finished data.
* 📋 **Smart Clipboard Sensing**: When you copy any download URL in Safari, Chrome, or Firefox, IDMac automatically detects it and prepares the download for you.
* 📊 **Live Thread Visualizer**: Watch your download happen in real time with our dynamic segment inspector displaying the live progress and byte chunks of every active stream.
* 🦊 **Mozilla Firefox Browser Extension**: Seamlessly captures file downloads from Firefox and accelerates them directly inside IDMac. Features right-click context menus, a live connection popup, and graceful fallback when offline.
* 📌 **macOS Menu Bar Companion & Dock Hiding**: Keep track of download progress and speeds directly from your menu bar. Close the window to hide IDMac from your Dock while downloads continue uninterrupted in the background.
* 🚀 **Launch at System Startup**: Seamlessly start IDMac in the background when logging into macOS so your download manager is always ready.
* 🔄 **Automatic Updates**: IDMac keeps itself up to date with built-in background update checking and one-click upgrades directly from official GitHub releases.
* 🎨 **Native Apple HIG Design**: Designed strictly according to Apple Human Interface Guidelines with full support for Light and Dark modes, custom Accent Colors, macOS notifications, and seamless keyboard shortcuts.
* 🔋 **Ultra-Low Battery & Memory Usage**: Optimized specifically for Apple Silicon (M1/M2/M3/M4). IDMac uses a fraction of the RAM and CPU compared to cross-platform download utilities.
* 🗂️ **Automatic File Organization**: Automatically organizes your finished downloads into categories like Compressed, Documents, Music, Programs, and Videos.

---

## 📥 Download & Installation

### Step 1: Download
Download the latest disk image (`.dmg`) from our official GitHub Releases:

👉 **[Download Latest IDMac Release](https://github.com/mrkheradmand/IDMac/releases/latest)**

### Step 2: Install
1. Double-click the downloaded `IDMac-X.Y.Z-macOS-arm64.dmg` to open it.
2. Drag the **IDMac** icon into your **Applications** folder.
3. Launch IDMac from your Applications folder or Spotlight (`⌘ Space`).

> [!NOTE]
> **First-Time Launch on macOS (Gatekeeper)**
>
> Because IDMac is an independent open-source project, macOS may show a prompt saying the app was downloaded from the internet:
> 1. If macOS prompts that the developer cannot be verified, open **System Settings** → **Privacy & Security**.
> 2. Scroll down to the **Security** section and click **Open Anyway**.
> 3. Alternatively, right-click (or Control-click) **IDMac.app** in Finder and choose **Open**.

---

## 🚀 Quick Start Guide

### Adding a Download
* **Toolbar Button**: Click the **Add** (`+`) button in the top toolbar.
* **Keyboard Shortcut**: Press `⌘N` from anywhere within the app.
* **Clipboard Paste**: Simply copy any link to your clipboard; opening the Add dialog will automatically detect and probe the file.

### Managing Your Downloads
* **Multi-Selection & Batch Actions**: Select multiple downloads using `Shift + Click` or `⌘ + Click` (or `⌘A` to select all) to pause, resume, reveal, or remove items together in batch.
* **Keyboard Delete**: Press the `Delete` key on your keyboard to instantly remove selected downloads from the list without deleting the downloaded files from disk.
* **Pause / Resume**: Select any active download and click **Pause** (`⏸`) or **Resume** (`▶`) in the toolbar, or right-click to choose from the context menu.
* **Stop All / Resume All**: Use the toolbar or the **Downloads** menu to quickly manage your entire download queue at once.
* **Automatic Queue Management**: Automatically caps simultaneous active downloads according to your preferences, holding extra items in a high-priority FIFO queue.
* **Open in Finder**: Double-click any completed download or right-click to reveal the downloaded files in Finder.

### Customizing Preferences (`⌘,`)
Open **IDMac** → **Settings** (or press `⌘,`) to tailor the app to your setup:
* **General**: Change your default Downloads folder, configure launch at system startup, customize menu bar icon visibility and background dock hiding, toggle clipboard monitoring, completion chimes, and native macOS notifications.
* **Acceleration**: Configure default connection streams (1 to 32 streams), maximum simultaneous downloads, and connection timeouts.
* **Browsers**: Install the Mozilla Firefox companion extension in one click, view connection status with the local loopback bridge, and inspect the Google Chrome Manifest V3 roadmap.
* **Updates**: Enable automatic update checking on launch, set check frequency, or check for new releases on demand.
* **Advanced**: Enable download speed caps, choose APFS file pre-allocation modes, and manage temporary cache files.

### Checking for Updates
Open **IDMac** → **About IDMac** or click **Check for Updates…** from the menu bar to view the current version and install the latest features and security fixes.

---

## 💻 System Requirements

* **Operating System**: macOS 14.0 Sonoma or macOS 15.0 Sequoia and later.
* **Hardware**: Any Mac with Apple Silicon (Apple M1, M2, M3, M4 series chip).

---

## 🤝 Community & Support

* **Issues & Bug Reports**: Found an issue or want to request a feature? Open a ticket on our [GitHub Issues](https://github.com/mrkheradmand/IDMac/issues).
* **Release Notes**: Check out what's new in every version in [versions.md](versions.md) or on the [GitHub Releases](https://github.com/mrkheradmand/IDMac/releases) page.

---

## 📄 License & Copyright

IDMac is open-source software released under the [MIT License](LICENSE).

Copyright © 2026 J Kheradmand. All rights reserved.
