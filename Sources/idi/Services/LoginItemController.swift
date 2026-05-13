import Foundation
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var statusMessage = "Launch at login is off"

    func apply(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                statusMessage = "Launch at login is on"
            } else {
                try SMAppService.mainApp.unregister()
                statusMessage = "Launch at login is off"
            }
        } catch {
            statusMessage = "Launch at login failed: \(error.localizedDescription)"
        }
    }
}
