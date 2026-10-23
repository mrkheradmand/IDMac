import SwiftUI
import SwiftData

@main
struct IDMacApp: App {
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
