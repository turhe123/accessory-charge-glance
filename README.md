# AccessoryChargeGlance

See the battery level of your Magic Mouse, keyboard, trackpad and other Bluetooth gear in the menu bar, with low alerts.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/License-MIT-green)
![Release](https://img.shields.io/github/v/release/turhe123/accessory-charge-glance)

## Why

macOS buries accessory batteries in the Bluetooth menu or a Notification Center widget. AccessoryChargeGlance is a free, open-source, 100% native, backend-free alternative to paid utilities in the *Battery & Power* category. It was inspired by AirBuddy ($9.99 one-time), and it focuses only on the battery readout and low-battery alerts, not on pairing or handoff.

## Features

- **Menu bar item** showing the lowest battery percentage among connected accessories. Optionally hide the text, or show an icon for every device instead of only the lowest.
- **Popover list** with each accessory's name, a device-type symbol, a colored battery bar (green, amber near the low threshold, red at or below it) and the percentage. A bolt marks charging devices.
- **Sorted lowest first**, with duplicate device names disambiguated by the last four characters of the Bluetooth address.
- **Low and critical alerts** as local notifications (defaults 20% and 10%, adjustable from 5 to 50%). Each alert fires once per drop. It resets when the level rises 5 points above the threshold or the device charges.
- **Optional full-charge notification** when a device reaches 100%.
- **Per-device mute switches** in Settings.
- **Recently seen** section: the last known level of each device is saved to a small JSON file in Application Support, and disconnected devices show dimmed with a "last seen" time.
- **Stale marker**: a clock icon for readings older than 30 minutes.
- **Refresh** every 1, 2 or 5 minutes, on demand with the refresh button, and immediately when a Bluetooth device connects or disconnects.
- **Launch at login** via `SMAppService`.
- **Clear states** for no Bluetooth hardware, no battery-reporting devices, Bluetooth access denied (with a button to open Privacy settings), and notifications denied (banner in Settings).
- Devices that don't report a level show "Battery not reported". A reading of 0% in the first seconds after connecting is treated as unknown, to avoid false alerts.

**Limitation:** only devices whose battery level macOS exposes through IOKit are shown. This typically covers Apple and many third-party Bluetooth mice, keyboards and trackpads. AirPods and some other devices are not covered and appear without a percentage, if at all.

## Screenshots

_Screenshots coming soon._

## Install

1. Download `AccessoryChargeGlance-macOS.zip` from the [latest release](https://github.com/turhe123/accessory-charge-glance/releases/latest).
2. Unzip it and move `AccessoryChargeGlance.app` to `/Applications`.
3. The app is open source and not notarized, so clear the quarantine flag:

   ```bash
   xattr -cr /Applications/AccessoryChargeGlance.app
   ```

4. The first time, right-click the app and choose **Open**.

## Build from source

Requires macOS 14+ and Xcode with Swift 5.9 or newer.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project AccessoryChargeGlance.xcodeproj -scheme AccessoryChargeGlance -configuration Release -derivedDataPath ./build build
```

The app is produced at `build/Build/Products/Release/AccessoryChargeGlance.app`.

## Permissions

AccessoryChargeGlance does **not** need Accessibility, Screen Recording or Microphone access. It may ask for:

- **Bluetooth**: macOS may prompt the first time the app uses IOBluetooth. The app reads the names and connection state of your paired accessories so it can show their batteries. If you deny it, the popover explains this and links to Privacy settings.
- **Notifications**: requested for low, critical and full-charge alerts. If denied, Settings shows a banner explaining how to turn them back on.
- **Login item**: only if you enable "Launch at login".

## Built with AI

AccessoryChargeGlance was written by [Claude Code](https://claude.com/claude-code) inside an automated pipeline, from a plain-English spec. No code, binaries or assets from any commercial app were used; it is a clean-room reimplementation of a feature set, not a copy.

What that means in practice:

- The full source is in this repo under the MIT license. Read it before you run it.
- No network calls, no analytics, no third-party dependencies. Only Apple frameworks.
- Ad-hoc signed and not notarized, which is why Gatekeeper warns on first launch.
- It has had less human review than a hand-written app. Bug reports and pull requests are welcome.

## Support ❤️

If this app is useful to you, you can support its development:

[Support Or (Leo) Davidai ❤️](https://ko-fi.com/leodavidai)

## License

MIT © Or Davidai Bachar
