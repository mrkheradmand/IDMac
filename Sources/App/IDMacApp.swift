import SwiftUI
import SwiftData
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false

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
}

@main
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
            CommandGroup(replacing: .newItem) {
                Button("Add New Download URL...") {
                    DownloadCoordinator.shared.isAddingDownloadSheetPresented = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Downloads") {
                Button("Resume All") {
                    // Triggered from coordinator
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Stop All") {
                    // Triggered from coordinator
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}
