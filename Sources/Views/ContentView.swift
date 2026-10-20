import SwiftUI

/// The popover: header with refresh, device list (connected + recently seen) and footer actions.
struct ContentView: View {
    @EnvironmentObject private var store: DeviceStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Accessory Batteries").font(.headline)
                Spacer()
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help("Refresh now")
                    .disabled(store.isRefreshing)
            }
            .padding(12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) { content }
                    .padding(12)
            }
            .frame(maxHeight: 380)
            .fixedSize(horizontal: false, vertical: true)
            Divider()
            footer.padding(10)
        }
        .frame(width: 320)
    }

    @ViewBuilder private var content: some View {
        if store.bluetoothDenied {
            Notice(symbol: "hand.raised", title: "Bluetooth access is off",
                   message: "Allow AccessoryChargeGlance under Privacy & Security › Bluetooth so it can see your paired accessories.") {
                Button("Open Privacy Settings") { Links.openSettingsPane("com.apple.preference.security?Privacy_Bluetooth") }
            }
        }
        if !store.bluetoothAvailable && store.devices.isEmpty {
            Notice(symbol: "antenna.radiowaves.left.and.right.slash", title: "No Bluetooth hardware",
                   message: "This Mac doesn't appear to have Bluetooth, so there are no wireless accessories to monitor.") { EmptyView() }
        } else if store.devices.isEmpty {
            Notice(symbol: "battery.0percent", title: "No battery-reporting accessories found",
                   message: "Connect a Bluetooth mouse, keyboard or trackpad and it will appear here.") { EmptyView() }
        } else {
            ForEach(store.connected) { DeviceRow(device: $0, name: store.displayName($0)) }
            if !store.recentlySeen.isEmpty {
                Text("Recently seen").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                ForEach(store.recentlySeen) { DeviceRow(device: $0, name: store.displayName($0)).opacity(0.5) }
            }
        }
    }

    private var footer: some View {
        HStack {
            SettingsLink { Text("Settings…") }
                .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
            Spacer()
            Button("Support / Donate ❤️") { Links.donate() }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .controlSize(.small)
    }
}

/// One accessory: symbol, name, percentage, charging / stale markers and a coloured bar.
struct DeviceRow: View {
    let device: DeviceReading
    let name: String
    @AppStorage(Prefs.lowThreshold) private var low = 20.0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: device.kind.symbol).frame(width: 22).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(name).lineLimit(1)
                    if device.charging { Image(systemName: "bolt.fill").foregroundStyle(.yellow).help("Charging") }
                    if device.isStale { Image(systemName: "clock").foregroundStyle(.secondary).help("Reading is over 30 minutes old") }
                    Spacer()
                    Text(device.percent.map { "\($0)%" } ?? "").monospacedDigit()
                }
                if let p = device.percent {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule().fill(color(for: p)).frame(width: geo.size.width * CGFloat(p) / 100)
                        }
                    }
                    .frame(height: 5)
                } else {
                    Text("Battery not reported").font(.caption).foregroundStyle(.secondary)
                }
                if !device.isConnected {
                    Text("Last seen \(device.lastSeen.formatted(.relative(presentation: .named)))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func color(for p: Int) -> Color {
        if Double(p) <= low { return .red }
        if Double(p) <= low + 10 { return .orange }
        return .green
    }
}

/// A centred icon + title + message block used for empty and error states.
struct Notice<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.secondary)
            Text(title).font(.subheadline.bold()).multilineTextAlignment(.center)
            Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            actions()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
