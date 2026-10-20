import CoreBluetooth
import Foundation
import IOBluetooth
import IOKit

/// A raw battery sample taken from the IOKit registry or the IOBluetooth paired list.
struct RawReading: Sendable {
    let address: String
    let name: String
    let percent: Int?
    let charging: Bool
}

/// Everything one refresh needs, gathered in a single pass so IOKit/IOBluetooth calls can run off the main thread.
struct ScanSnapshot: Sendable {
    let hasBluetooth: Bool
    let bluetoothDenied: Bool
    let registry: [RawReading]
    let paired: [PairedDevice]
}

struct PairedDevice: Sendable {
    let address: String
    let name: String
    let connected: Bool
}

/// Reads battery information for Bluetooth accessories from the IOKit registry and IOBluetooth.
enum BatteryScanner {
    /// Registry classes known to publish `BatteryPercent` for HID accessories.
    private static let serviceClasses = [
        "AppleDeviceManagementHIDEventService", "AppleHSBluetoothDevice",
        "IOAppleBluetoothHIDDriver", "BNBMouseDevice", "BNBTrackpadDevice", "AppleBluetoothHIDKeyboard",
    ]

    /// Normalises addresses so IOKit (`aa:bb…`) and IOBluetooth (`aa-bb…`) forms match.
    static func normalize(_ address: String) -> String {
        address.lowercased().replacingOccurrences(of: ":", with: "-")
    }

    /// Accessories that expose a battery percentage through the IORegistry.
    static func scanRegistry() -> [RawReading] {
        var found: [String: RawReading] = [:]
        for cls in serviceClasses {
            guard let matching = IOServiceMatching(cls) else { continue }
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iterator) }
            while case let service = IOIteratorNext(iterator), service != 0 {
                defer { IOObjectRelease(service) }
                if let reading = reading(for: service), found[reading.address] == nil {
                    found[reading.address] = reading
                }
            }
        }
        return Array(found.values)
    }

    private static func reading(for service: io_object_t) -> RawReading? {
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any],
              let percent = (dict["BatteryPercent"] as? NSNumber)?.intValue else { return nil }
        let name = (dict["Product"] as? String) ?? "Bluetooth Accessory"
        let rawAddress = (dict["DeviceAddress"] as? String) ?? (dict["SerialNumber"] as? String) ?? name
        let flags = (dict["BatteryStatusFlags"] as? NSNumber)?.intValue ?? 0
        return RawReading(address: normalize(rawAddress), name: name,
                          percent: max(0, min(100, percent)), charging: flags & 0b11 != 0)
    }

    /// Paired Bluetooth devices with their connection state (no battery level).
    /// The first IOBluetooth call can block until the user answers the Bluetooth permission prompt,
    /// so callers must not run this on the main thread at launch.
    static func pairedDevices() -> [PairedDevice] {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }
        return devices.compactMap { device in
            guard let address = device.addressString else { return nil }
            return PairedDevice(address: normalize(address), name: device.name ?? "Bluetooth Device",
                                connected: device.isConnected())
        }
    }

    /// One full pass over IOKit and IOBluetooth. Safe to call from a background task.
    static func snapshot() -> ScanSnapshot {
        ScanSnapshot(hasBluetooth: hasBluetooth, bluetoothDenied: bluetoothDenied,
                     registry: scanRegistry(), paired: pairedDevices())
    }

    /// Whether this Mac has a Bluetooth controller at all.
    static var hasBluetooth: Bool { IOBluetoothHostController.default() != nil }

    /// Whether the user denied (or a policy restricts) Bluetooth access for this app.
    static var bluetoothDenied: Bool {
        let auth = CBManager.authorization
        return auth == .denied || auth == .restricted
    }
}

/// Listens for IOBluetooth connect / disconnect events and reports them through `onChange`.
final class BluetoothWatcher: NSObject {
    var onChange: (() -> Void)?
    private var connectNote: IOBluetoothUserNotification?
    private var disconnectNotes: [IOBluetoothUserNotification] = []

    func start() {
        connectNote = IOBluetoothDevice.register(forConnectNotifications: self,
                                                 selector: #selector(deviceConnected(_:device:)))
    }

    @objc private func deviceConnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        if let n = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:))) {
            disconnectNotes.append(n)
        }
        onChange?()
    }

    @objc private func deviceDisconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        note.unregister()
        disconnectNotes.removeAll { $0 === note }
        onChange?()
    }
}
