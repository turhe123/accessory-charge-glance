import AppKit
import SwiftUI

/// Entry point: a menu bar extra with a list popover plus a Settings window.
@main
struct AccessoryChargeGlanceApp: App {
    @StateObject private var store = DeviceStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView().environmentObject(store)
        } label: {
            MenuBarLabel().environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(store)
        }
    }
}

/// Shared helpers for opening external destinations.
enum Links {
    static func donate() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }

    static func openSettingsPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:\(anchor)") { NSWorkspace.shared.open(url) }
    }
}

/// The menu bar item: lowest battery (icon + %) or one icon per connected device.
struct MenuBarLabel: View {
    @EnvironmentObject private var store: DeviceStore
    @AppStorage(Prefs.showPercent) private var showPercent = true
    @AppStorage(Prefs.showAllIcons) private var showAllIcons = false

    var body: some View {
        let devices = store.connected
        if showAllIcons && !devices.isEmpty {
            devices.reduce(Text("")) { text, d in
                let pct = showPercent ? (d.percent.map { "\($0)%" } ?? "–") : ""
                return text + Text(Image(systemName: d.kind.symbol)) + Text(pct + " ")
            }
        } else {
            HStack(spacing: 3) {
                Image(systemName: Self.batterySymbol(store.lowestPercent))
                if showPercent, let p = store.lowestPercent { Text("\(p)%") }
            }
        }
    }

    static func batterySymbol(_ percent: Int?) -> String {
        guard let p = percent else { return "battery.100percent" }
        switch p {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
