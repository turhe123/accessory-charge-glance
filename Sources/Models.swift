import Foundation

/// Broad category of an accessory, used to choose an SF Symbol.
enum DeviceKind: String, Codable {
    case mouse, keyboard, trackpad, audio, gamepad, other

    /// Guesses the kind from the product name reported by macOS.
    static func guess(from name: String) -> DeviceKind {
        let n = name.lowercased()
        if n.contains("mouse") { return .mouse }
        if n.contains("trackpad") { return .trackpad }
        if n.contains("keyboard") { return .keyboard }
        if n.contains("airpods") || n.contains("headphone") || n.contains("buds") || n.contains("beats") { return .audio }
        if n.contains("controller") || n.contains("gamepad") { return .gamepad }
        return .other
    }

    var symbol: String {
        switch self {
        case .mouse: return "magicmouse"
        case .keyboard: return "keyboard"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .audio: return "headphones"
        case .gamepad: return "gamecontroller"
        case .other: return "dot.radiowaves.left.and.right"
        }
    }
}

/// The latest known battery state of one accessory, keyed by its Bluetooth address.
struct DeviceReading: Codable, Identifiable, Equatable {
    var address: String
    var name: String
    var kind: DeviceKind
    var percent: Int?
    var charging: Bool
    var isConnected: Bool
    var lastSeen: Date
    /// When a battery percentage was last actually read from the system.
    var lastReading: Date?

    var id: String { address }

    /// A connected device whose shown percentage is older than 30 minutes.
    var isStale: Bool {
        guard isConnected, percent != nil, let lastReading else { return false }
        return Date().timeIntervalSince(lastReading) > 30 * 60
    }
}

/// UserDefaults keys and their default values.
enum Prefs {
    static let lowThreshold = "lowThreshold"
    static let criticalThreshold = "criticalThreshold"
    static let criticalAlerts = "criticalAlertsEnabled"
    static let fullAlerts = "fullChargeAlertsEnabled"
    static let showPercent = "showPercentInMenuBar"
    static let showAllIcons = "showAllIcons"
    static let refreshMinutes = "refreshMinutes"
    static let mutedDevices = "mutedDevices"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            lowThreshold: 20.0, criticalThreshold: 10.0, criticalAlerts: true, fullAlerts: false,
            showPercent: true, showAllIcons: false, refreshMinutes: 2, mutedDevices: "",
        ])
    }

    /// Addresses of devices whose alerts are muted, stored comma-separated.
    static func mutedSet(_ raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init))
    }
}
