<div align="center">

<img src="assets/gapwise-ios.svg" width="116" alt="Gapwise for iOS logo" />

# Gapwise for iOS

### The native iOS client for Gapwise.

**A privacy-first Swift + SwiftUI app for understanding your timetable, the time between classes, and the rest of your day.**

[![iOS](https://img.shields.io/badge/iOS-Native-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-Native-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Native_UI-0D96F6?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![MIT](https://img.shields.io/badge/License-MIT-111111?style=for-the-badge)](LICENSE)

<sub>Swift · SwiftUI · MapLibre · Supabase · Keychain</sub>

<br />

**[Gapwise](https://gapwise.ca)** · **[AI](https://ai.gapwise.ca)** · **[Data](https://data.gapwise.ca)** · **[Docs](https://docs.gapwise.ca)** · **[Status](https://status.gapwise.ca)**

</div>

---

## What Gapwise for iOS is

Gapwise for iOS is the native iPhone client for **Gapwise**.

This repository is the home of the iOS application and its development. The goal is to bring the core Gapwise experience to a phone-native SwiftUI interface while remaining aligned with the wider Gapwise product.

The app is intended to be a real native iOS application rather than a WebView wrapper, with navigation, storage, authentication, rendering, interactions, and platform integration designed for iOS.

---

## Product direction

The iOS client is being designed around the same core principles as Gapwise:

- **Fast to open and easy to understand.** The important parts of the day should be immediately visible.
- **Native interaction.** Navigation, gestures, sheets, system controls, theming, and lifecycle behavior should feel natural on iPhone.
- **Local-first timetable handling.** Timetable data should remain useful without requiring a constant connection.
- **Optional account continuity.** The core timetable experience should not depend on having a Gapwise account.
- **Deterministic planning.** Timetable arithmetic, gap boundaries, route timing, and other core calculations should remain explicit and testable.
- **Visual consistency.** The app should remain recognizably Gapwise while adapting naturally to Apple's platform conventions.

---

## Planned app surface

The native iOS client is intended to cover the core Gapwise experience, including:

- **Today** for the current day's schedule and immediate context;
- **Timetable** for imported ACORN calendar data;
- **Gaps** for time-between-class planning;
- **Map** for interactive location tools;
- **Settings** for appearance, account, sync, timetable, routing, planning, privacy, exports, and integrations;
- light and dark appearance;
- privacy-first local timetable persistence;
- optional encrypted Gapwise account sync.

The iOS client is at an early stage. This README describes the intended product direction rather than claiming that these surfaces are already implemented.

---

## Technology direction

Gapwise for iOS is intended to use modern native Apple tooling:

- **Swift**
- **SwiftUI**
- **MapLibre Native**
- **Keychain / platform-secure storage**
- **Supabase Auth + encrypted Gapwise sync**

The architecture will keep domain logic, persistence, account/sync code, navigation, and feature UI separated as the application grows.

---

## Privacy and security

The iOS client will follow Gapwise's privacy-first approach and minimize unnecessary collection or transmission of timetable data.

The intended trust model is straightforward: local timetable operations should stay local where possible, privileged service credentials must never be embedded in the app, account functionality remains optional, and cloud sync should preserve clear encryption boundaries.

---

## Development

Native iOS development will live in this repository as the client is built out in Swift and SwiftUI.

```bash
git clone https://github.com/Gapwise-for-UTM/ios.git
cd ios
```

---

## Gapwise ecosystem

| Repository | Role | Primary surface |
| --- | --- | --- |
| **[`gapwise`](https://github.com/Gapwise-for-UTM/gapwise)** | Core web/PWA product and canonical Gapwise platform | [gapwise.ca](https://gapwise.ca) |
| **[`android`](https://github.com/Gapwise-for-UTM/android)** | Native Android client | Android app |
| **[`ios`](https://github.com/Gapwise-for-UTM/ios)** | Native iOS client | iOS app |
| **[`gapwise-ai`](https://github.com/Gapwise-for-UTM/gapwise-ai)** | Permissioned AI and MCP integration layer | [ai.gapwise.ca](https://ai.gapwise.ca) |
| **[`gapwise-data`](https://github.com/Gapwise-for-UTM/gapwise-data)** | Open data, provenance, schema, and validation | [data.gapwise.ca](https://data.gapwise.ca) |
| **[`gapwise-docs`](https://github.com/Gapwise-for-UTM/gapwise-docs)** | Canonical developer documentation | [docs.gapwise.ca](https://docs.gapwise.ca) |
| **[`gapwise-status`](https://github.com/Gapwise-for-UTM/gapwise-status)** | Independent service-health monitoring and incident communication | [status.gapwise.ca](https://status.gapwise.ca) |

---

## Independent project

> **Gapwise is an independent student software project created by Andrew Muratov. It is not affiliated with, endorsed by, or an official service of the University of Toronto.**

## License

Original project code and documentation are available under the [MIT License](LICENSE).

<div align="center">

**Built for the spaces between classes — now coming natively to iOS.**

[Open Gapwise →](https://gapwise.ca)

</div>
