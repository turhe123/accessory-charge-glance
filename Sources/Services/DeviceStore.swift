import Foundation

/// Observable model mapping each device address to its latest reading; drives polling and persistence.
@MainActor
final class DeviceStore: ObservableObject {
    @Published private(set) var devices: [DeviceReading] = []
    @Published private(set) var bluetoothAvailable = true
    @Published private(set) var bluetoothDenied = false
    @Published private(set) var isRefreshing = false

    let alerts = AlertManager()
    private var records: [String: DeviceReading] = [:]
    private var displayNames: [String: String] = [:]
    private var firstConnected: [String: Date] = [:]
    private var timer: Timer?
    private var timerMinutes = 0
    private let watcher = BluetoothWatcher()
    private var defaultsObserver: NSObjectProtocol?

    var connected: [DeviceReading] { devices.filter(\.isConnected) }
    var recentlySeen: [DeviceReading] { devices.filter { !$0.isConnected } }
    var lowestPercent: Int? { connected.compactMap(\.percent).min() }

    init() {
        Prefs.registerDefaults()
        records = Self.load()
        rebuild()
        watcher.onChange = { [weak self] in
            Task { @MainActor in
                self?.refresh()
                // Battery properties often appear a few seconds after the connection itself.
                try? await Task.sleep(for: .seconds(4))
                self?.refresh()
            }
        }
        watcher.start()
        scheduleTimer()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleTimer() }
        }
        alerts.requestAuthorizationIfNeeded()
        refresh()
    }

    func displayName(_ d: DeviceReading) -> String { displayNames[d.address] ?? d.name }

    private func scheduleTimer() {
        let minutes = max(1, UserDefaults.standard.integer(forKey: Prefs.refreshMinutes))
        guard minutes != timerMinutes else { return }
        timerMinutes = minutes
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Re-reads IOKit and IOBluetooth, updates records, fires alerts and saves.
    func refresh() {
        isRefreshing = true
        defer { isRefreshing = false }
        bluetoothAvailable = BatteryScanner.hasBluetooth
        bluetoothDenied = BatteryScanner.bluetoothDenied
        let now = Date()
        var seen = Set<String>()

        for raw in BatteryScanner.scanRegistry() {
            seen.insert(raw.address)
            let since = firstConnected[raw.address] ?? now
            firstConnected[raw.address] = since
            // A zero right after connecting is usually a placeholder, not a real reading.
            let percent = (raw.percent == 0 && now.timeIntervalSince(since) < 10) ? nil : raw.percent
            update(raw.address, name: raw.name, percent: percent, charging: raw.charging, now: now)
        }
        for paired in BatteryScanner.pairedDevices() where paired.connected && !seen.contains(paired.address) {
            seen.insert(paired.address)
            firstConnected[paired.address] = firstConnected[paired.address] ?? now
            update(paired.address, name: paired.name, percent: nil, charging: false, now: now)
        }
        for key in records.keys where !seen.contains(key) {
            records[key]?.isConnected = false
            firstConnected[key] = nil
        }
        // Forget disconnected devices that never reported a battery level.
        records = records.filter { $0.value.isConnected || $0.value.lastReading != nil }

        rebuild()
        let muted = Prefs.mutedSet(UserDefaults.standard.string(forKey: Prefs.mutedDevices) ?? "")
        for d in connected { alerts.evaluate(d, displayName: displayName(d), muted: muted.contains(d.address)) }
        save()
    }

    private func update(_ address: String, name: String, percent: Int?, charging: Bool, now: Date) {
        var rec = records[address] ?? DeviceReading(address: address, name: name, kind: .guess(from: name),
                                                    percent: nil, charging: false, isConnected: true, lastSeen: now)
        rec.name = name
        rec.kind = .guess(from: name)
        rec.isConnected = true
        rec.lastSeen = now
        rec.charging = charging
        if let percent {
            rec.percent = percent
            rec.lastReading = now
        }
        records[address] = rec
    }

    /// Sorts lowest battery first and disambiguates duplicate names with the address tail.
    private func rebuild() {
        devices = records.values.sorted {
            switch ($0.percent, $1.percent) {
            case let (a?, b?) where a != b: return a < b
            case (nil, _?): return false
            case (_?, nil): return true
            default: return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
        let counts = Dictionary(grouping: devices, by: \.name).mapValues(\.count)
        displayNames = Dictionary(uniqueKeysWithValues: devices.map { d in
            let tail = d.address.replacingOccurrences(of: "-", with: "").suffix(4).uppercased()
            return (d.address, (counts[d.name] ?? 0) > 1 ? "\(d.name) (\(tail))" : d.name)
        })
    }

    // MARK: Persistence

    private static var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("AccessoryChargeGlance", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("devices.json")
    }

    private static func load() -> [String: DeviceReading] {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              var decoded = try? JSONDecoder().decode([String: DeviceReading].self, from: data) else { return [:] }
        for key in decoded.keys { decoded[key]?.isConnected = false }
        return decoded
    }

    private func save() {
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
