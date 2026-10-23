import SwiftUI
import SwiftData
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.register(defaults: [
            "showMenuBarIcon": true,
            "keepRunningInMenuBar": true,
            "hideDockIconWhenClosed": true
        ])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        MenuBarManager.shared.setupStatusBarItem()

        // Listen for windows becoming key/main and permanently disallow tabbing
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            if let window = notif.object as? NSWindow {
                window.tabbingMode = .disallowed
                window.tabbingIdentifier = ""
            }
            self?.cleanAllMenus()
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            if let window = notif.object as? NSWindow {
                window.tabbingMode = .disallowed
                window.tabbingIdentifier = ""
            }
            self?.cleanAllMenus()
        }

        // Whenever menus are tracked or updated, intercept and strip tab bar items
        NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanAllMenus()
        }

        NotificationCenter.default.addObserver(
            forName: NSMenu.didAddItemNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanAllMenus()
        }

        DispatchQueue.main.async { [weak self] in
            for window in NSApplication.shared.windows {
                window.tabbingMode = .disallowed
                window.tabbingIdentifier = ""
            }
            self?.cleanAllMenus()
            UpdateManager.shared.startBackgroundCheck()
        }
    }

    func cleanAllMenus() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }
        for item in mainMenu.items {
            if let submenu = item.submenu {
                cleanMenu(submenu)
            }
        }
    }

    func cleanMenu(_ menu: NSMenu) {
        let toRemove = menu.items.filter { menuItem in
            let title = menuItem.title.lowercased()
            let actionName = menuItem.action.map { NSStringFromSelector($0).lowercased() } ?? ""
            return title.contains("tab bar") || title.contains("all tabs") ||
                   actionName.contains("tabbar") || actionName.contains("taboverview")
        }
        for rm in toRemove {
            menu.removeItem(rm)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MenuBarManager.shared.showMainWindow()
        }
        return true
    }
}

@main
@MainActor
struct IDMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DownloadItem.self,
            DownloadSegment.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1060, height: 640)
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About IDMac") {
                    AboutWindowController.shared.show()
                }
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    AboutWindowController.shared.show()
                    Task {
                        await UpdateManager.shared.checkForUpdates(manual: true)
                    }
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("Add New Download URL...") {
                    DownloadCoordinator.shared.isAddingDownloadSheetPresented = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Downloads") {
                Button("Resume All") {
                    DownloadCoordinator.shared.resumeAllDownloads()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Stop All") {
                    DownloadCoordinator.shared.pauseAllDownloads()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}
