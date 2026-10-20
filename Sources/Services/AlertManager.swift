import Foundation
import UserNotifications

/// Posts deduplicated low, critical and full-charge notifications.
final class AlertManager: NSObject, UNUserNotificationCenterDelegate {
    /// Which alerts have already fired for a device since it last recovered.
    private struct Fired { var low = false, critical = false, full = false }
    private var fired: [String: Fired] = [:]
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [center] settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func isDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    /// Compares a fresh reading to the thresholds and notifies on new crossings.
    func evaluate(_ d: DeviceReading, displayName: String, muted: Bool) {
        guard d.isConnected, let p = d.percent else { return }
        let defaults = UserDefaults.standard
        let low = Int(defaults.double(forKey: Prefs.lowThreshold))
        let critical = Int(defaults.double(forKey: Prefs.criticalThreshold))
        var s = fired[d.address] ?? Fired()

        // Reset once the level recovers by 5 points or the device starts charging.
        if d.charging || p >= low + 5 { s.low = false }
        if d.charging || p >= critical + 5 { s.critical = false }
        if p < 95 { s.full = false }

        if !d.charging && defaults.bool(forKey: Prefs.criticalAlerts) && p <= critical && !s.critical {
            s.critical = true
            s.low = true
            if !muted { post("\(displayName) battery critical", "Only \(p)% left — charge it soon.", d.address) }
        } else if !d.charging && p <= low && !s.low {
            s.low = true
            if !muted { post("\(displayName) battery low", "\(p)% remaining.", d.address) }
        }
        if defaults.bool(forKey: Prefs.fullAlerts) && p >= 100 && !s.full {
            s.full = true
            if !muted { post("\(displayName) fully charged", "You can unplug it now.", d.address) }
        }
        fired[d.address] = s
    }

    private func post(_ title: String, _ body: String, _ address: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: "\(address)-\(UUID().uuidString)", content: content, trigger: nil)
        center.add(request) { _ in }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
