import AppKit
import SwiftUI

@MainActor
public final class MenuBarManager: NSObject, NSMenuDelegate, NSWindowDelegate {
    public static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    public weak var mainWindow: NSWindow?

    private override init() {
        super.init()
    }

    public func setupStatusBarItem() {
        let isEnabled = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        if isEnabled {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                if let button = item.button {
                    if let image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "IDMac") {
                        image.isTemplate = true
                        button.image = image
                        button.imagePosition = .imageOnly
                    }
                }
                let menu = NSMenu()
                menu.delegate = self
                item.menu = menu
                statusItem = item
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            // Ensure Dock icon is visible if menu bar icon is removed
            NSApp.setActivationPolicy(.regular)
        }
    }

    public func registerMainWindow(_ window: NSWindow) {
        guard !(window is NSPanel) else { return }
        if self.mainWindow !== window {
            self.mainWindow = window
            window.delegate = self
        }
    }

    // MARK: - NSMenuDelegate
    public func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        populateMenu(menu)
    }

    private func populateMenu(_ menu: NSMenu) {
        let (activeCount, totalSpeed) = DownloadCoordinator.shared.getActiveDownloadStats()

        // Status Header Item
        let statusTitle: String
        if activeCount > 0 {
            let speedStr = ByteCountFormatter.string(fromByteCount: Int64(totalSpeed), countStyle: .file)
            statusTitle = "IDMac: Downloading (\(activeCount)) • \(speedStr)/s"
        } else {
            statusTitle = "IDMac: Idle"
        }

        let headerItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Show Main Window
        let showItem = NSMenuItem(title: "Show IDMac", action: #selector(showMainWindowAction), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        // Add URL
        let addItem = NSMenuItem(title: "Add Download URL…", action: #selector(addDownloadAction), keyEquivalent: "n")
        addItem.keyEquivalentModifierMask = [.command]
        addItem.target = self
        menu.addItem(addItem)

        menu.addItem(NSMenuItem.separator())

        // Resume All / Pause All
        let resumeItem = NSMenuItem(title: "Resume All", action: #selector(resumeAllAction), keyEquivalent: "")
        resumeItem.target = self
        menu.addItem(resumeItem)

        let pauseItem = NSMenuItem(title: "Pause All", action: #selector(pauseAllAction), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.isEnabled = activeCount > 0
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Check for updates
        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkUpdatesAction), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit IDMac", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions
    @objc public func showMainWindowAction() {
        showMainWindow()
    }

    public func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeKey }) {
                mainWindow = window
                window.delegate = self
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    @objc public func addDownloadAction() {
        showMainWindow()
        DownloadCoordinator.shared.isAddingDownloadSheetPresented = true
    }

    @objc public func resumeAllAction() {
        DownloadCoordinator.shared.resumeAllDownloads()
    }

    @objc public func pauseAllAction() {
        DownloadCoordinator.shared.pauseAllDownloads()
    }

    @objc public func openSettingsAction() {
        showMainWindow()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc public func checkUpdatesAction() {
        AboutWindowController.shared.show()
        Task {
            await UpdateManager.shared.checkForUpdates(manual: true)
        }
    }

    @objc public func quitAction() {
        NSApp.terminate(nil)
    }

    // MARK: - Window Close & Dock Visibility Management
    public func handleWindowShouldClose(_ window: NSWindow) -> Bool {
        guard window === mainWindow else { return true }

        let keepInMenuBar = UserDefaults.standard.object(forKey: "keepRunningInMenuBar") as? Bool ?? true
        let hideDock = UserDefaults.standard.object(forKey: "hideDockIconWhenClosed") as? Bool ?? true
        let menuBarEnabled = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true

        if keepInMenuBar && menuBarEnabled {
            window.orderOut(nil)
            if hideDock {
                NSApp.setActivationPolicy(.accessory)
            }
            return false
        }

        return true
    }

    // MARK: - NSWindowDelegate
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        return handleWindowShouldClose(sender)
    }
}

