import Foundation
import UserNotifications

@MainActor
final class NotificationController {
    private var lastNotificationDate: Date?
    private let cooldown: TimeInterval = 300

    func handle(snapshot: TelemetrySnapshot, preferences: PreferencesModel) {
        guard preferences.notificationsEnabled else { return }
        let thresholdModules = snapshot.modules.filter { module in
            Self.exceedsThreshold(module: module, preferences: preferences)
        }
        guard snapshot.healthState != .normal || !thresholdModules.isEmpty else { return }
        guard shouldNotify else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            let highlighted = thresholdModules.first ?? snapshot.modules.first(where: { $0.healthState == snapshot.healthState })
            content.title = "idi \(snapshot.healthState.rawValue)"
            content.body = highlighted.map { "\($0.name): \($0.value) · \($0.detail)" } ?? "System state changed"
            content.sound = .default
            let request = UNNotificationRequest(identifier: "idi-health-\(Date().timeIntervalSince1970)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
        lastNotificationDate = Date()
    }

    static func exceedsThreshold(module: TelemetryModule, preferences: PreferencesModel) -> Bool {
        switch module.name {
        case "CPU": return module.latestSample >= preferences.cpuWarningThreshold
        case "Memory": return module.latestSample >= preferences.memoryWarningThreshold
        case "Disk": return module.latestSample >= preferences.diskWarningThreshold
        case "Battery": return 1 - module.latestSample <= preferences.batteryLowThreshold
        case "Sensors": return module.latestSample >= preferences.sensorHighThreshold
        default: return false
        }
    }

    private var shouldNotify: Bool {
        guard let lastNotificationDate else { return true }
        return Date().timeIntervalSince(lastNotificationDate) > cooldown
    }
}
