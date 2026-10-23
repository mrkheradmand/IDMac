import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()

    @Published public var isEnabled: Bool = false

    private init() {
        self.isEnabled = checkStatus()
    }

    public func refresh() {
        self.isEnabled = checkStatus()
    }

    public func setEnabled(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to update launch at login status: \(error.localizedDescription)")
        }
        self.isEnabled = checkStatus()
    }

    private func checkStatus() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}

