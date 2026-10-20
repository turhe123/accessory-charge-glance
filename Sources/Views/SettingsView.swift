import ServiceManagement
import SwiftUI

/// Settings window (⌘,): thresholds, alert toggles, menu bar style, refresh interval, mutes and login item.
struct SettingsView: View {
    @EnvironmentObject private var store: DeviceStore
    @AppStorage(Prefs.lowThreshold) private var low = 20.0
    @AppStorage(Prefs.criticalThreshold) private var critical = 10.0
    @AppStorage(Prefs.criticalAlerts) private var criticalAlerts = true
    @AppStorage(Prefs.fullAlerts) private var fullAlerts = false
    @AppStorage(Prefs.showPercent) private var showPercent = true
    @AppStorage(Prefs.showAllIcons) private var showAllIcons = false
    @AppStorage(Prefs.refreshMinutes) private var refreshMinutes = 2
    @AppStorage(Prefs.mutedDevices) private var mutedRaw = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var notificationsDenied = false

    var body: some View {
        Form {
            Section("Alerts") {
                if notificationsDenied {
                    Label("Notifications are turned off. Enable them in System Settings › Notifications › AccessoryChargeGlance.",
                          systemImage: "bell.slash")
                        .foregroundStyle(.orange)
                    Button("Open Notification Settings") { Links.openSettingsPane("com.apple.preference.notifications") }
                }
                Slider(value: $low, in: 5...50, step: 1) { Text("Low threshold: \(Int(low))%") }
                    .onChange(of: low) { _, new in if critical >= new { critical = max(5, new - 1) } }
                Toggle("Critical alert", isOn: $criticalAlerts)
                Slider(value: $critical, in: 5...50, step: 1) { Text("Critical threshold: \(Int(critical))%") }
                    .disabled(!criticalAlerts)
                    .onChange(of: critical) { _, new in if new >= low { low = min(50, new + 1) } }
                Toggle("Notify when a device is fully charged", isOn: $fullAlerts)
            }
            Section("Menu Bar") {
                Toggle("Show percentage text", isOn: $showPercent)
                Toggle("Show an icon for every device (instead of only the lowest)", isOn: $showAllIcons)
                Picker("Refresh every", selection: $refreshMinutes) {
                    Text("1 minute").tag(1)
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                }
            }
            Section {
                if store.devices.isEmpty {
                    Text("No devices seen yet.").foregroundStyle(.secondary)
                }
                ForEach(store.devices) { d in
                    Toggle(store.displayName(d), isOn: alertBinding(for: d.address))
                }
            } header: { Text("Device Alerts") } footer: { Text("Turn a device off to mute its notifications.") }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            }
            Section("About") {
                Text("AccessoryChargeGlance shows only accessories whose battery level macOS exposes through IOKit — typically Apple and many third-party Bluetooth mice, keyboards and trackpads. AirPods and some other devices are not covered and appear without a percentage, if at all.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Support / Donate ❤️") { Links.donate() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 600)
        .task { notificationsDenied = await store.alerts.isDenied() }
    }

    private func alertBinding(for address: String) -> Binding<Bool> {
        Binding {
            !Prefs.mutedSet(mutedRaw).contains(address)
        } set: { enabled in
            var set = Prefs.mutedSet(mutedRaw)
            if enabled { set.remove(address) } else { set.insert(address) }
            mutedRaw = set.sorted().joined(separator: ",")
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        let isEnabled = SMAppService.mainApp.status == .enabled
        guard on != isEnabled else { return }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't update login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
