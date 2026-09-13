<div align="center">

<img src="assets/gapwise-ios.svg" width="116" alt="Gapwise for iOS logo" />

# Gapwise for iOS

### The native iOS client for Gapwise.

**A privacy-first Swift + SwiftUI app for University of Toronto timetables, designed around fast local interaction and a UTM-focused campus layer.**

[![iOS](https://img.shields.io/badge/iOS-Native-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-Native-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Native_UI-0D96F6?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![MIT](https://img.shields.io/badge/License-MIT-111111?style=for-the-badge)](LICENSE)

<sub>Swift · SwiftUI · Apple platform APIs · privacy-first local state</sub>

<br />

**[Gapwise](https://gapwise.ca)** · **[Android](https://github.com/Gapwise-for-UTM/android)** · **[iOS](https://github.com/Gapwise-for-UTM/ios)** · **[AI](https://ai.gapwise.ca)** · **[Data](https://data.gapwise.ca)** · **[Docs](https://docs.gapwise.ca)** · **[Status](https://status.gapwise.ca)**

</div>

---

## What Gapwise for iOS is

Gapwise for iOS is the native iPhone client for **Gapwise**, a privacy-first timetable and campus-intelligence platform for University of Toronto students.

This repository is the home of the Swift/SwiftUI application as it is built. The timetable experience is intended to support **UTM, UTSG, UTSC, and mixed-campus schedules**, while the first native campus map and routing work stays **UTM-focused** until equally grounded campus data exists elsewhere.

The goal is a real native iOS application rather than a WebView wrapper: navigation, storage, rendering, accessibility, interactions, and platform integration should be designed for iPhone while staying aligned with canonical Gapwise contracts.

---

## Current status

The iOS client is at an **early repository/bootstrap stage**. The brand, product boundary, technology direction, and ecosystem integration are established here; the application features described below are the implementation target, not a claim that they are already shipped.

That distinction is intentional. Gapwise documentation should describe what exists and what is planned separately rather than presenting roadmap work as completed functionality.

---

## Product direction

The native iOS experience is being designed around the same principles as the Android and web clients:

- **Fast to open and easy to understand.** The important parts of the day should be immediately visible.
- **All-campus timetable identity.** UTM, UTSG, and UTSC meetings should preserve their actual campus and source location.
- **UTM map honesty.** Map/routing features should only claim the campus coverage backed by current first-party data.
- **Local-first timetable handling.** Import and core schedule use should work without unnecessary network transmission.
- **Optional account continuity.** A Gapwise account should enhance continuity rather than gate the core timetable experience.
- **Deterministic planning.** Timetable arithmetic, gap boundaries, route timing, and feasibility should remain explicit and testable.
- **Native interaction.** Navigation, gestures, sheets, system pickers, accessibility, appearance, and lifecycle behavior should feel natural on iOS.

---

## Planned app surface

The native iOS client is intended to grow toward the core Gapwise experience:

- **Today** for the current day's schedule and immediate context;
- **Timetable** for local ACORN `.ics` import across U of T campuses;
- **Gaps** for deterministic time-between-class planning;
- **Map** for UTM-focused campus navigation and route context;
- **Settings** for appearance, privacy, timetable, account/sync, routing, exports, and integrations as those systems are implemented;
- light and dark appearance;
- privacy-first local persistence;
- optional, explicitly scoped account continuity.

These are roadmap targets. This README will be tightened as implementation lands so the “current” surface never outruns the code.

---

## Technology direction

Gapwise for iOS is intended to use modern native Apple tooling:

- **Swift**
- **SwiftUI**
- Apple document-picker and lifecycle APIs
- **Keychain / platform-secure storage** where secret material is eventually required
- a native map stack compatible with canonical Gapwise UTM data and routing semantics
- optional Gapwise account integration only after its security boundary is implemented and reviewed

The architecture should keep domain models, timetable parsing, persistence, account/sync, navigation, map integration, and feature UI separated as the application grows.

---

## Privacy and security

The iOS client follows the same security posture as the wider Gapwise ecosystem:

- minimize collection and transmission of student timetable data;
- keep original ACORN calendar handling local where practical;
- never embed privileged service credentials in the application;
- distinguish local-only features from optional account/cloud behavior;
- use platform-backed secret storage when secret material is actually introduced;
- preserve campus/source identity rather than inventing location certainty;
- make permissions narrow, understandable, and revocable.

No persistence, encryption, account-sync, or map capability should be described as implemented before the corresponding code and verification exist.

---

## Development

Native iOS development lives in this repository as the client is built out in Swift and SwiftUI.

```bash
git clone https://github.com/Gapwise-for-UTM/ios.git
cd ios
```

As the Xcode project and build pipeline land, this section will carry the exact supported Xcode/iOS requirements and verification commands.

---

## Gapwise ecosystem

| Repository | Role | Primary surface |
| --- | --- | --- |
| **[`gapwise`](https://github.com/Gapwise-for-UTM/gapwise)** | Core web/PWA, canonical timetable/gap/routing semantics, public API, OpenAPI, and SDK source | [gapwise.ca](https://gapwise.ca) / [api.gapwise.ca](https://api.gapwise.ca/v1) |
| **[`android`](https://github.com/Gapwise-for-UTM/android)** | Native Kotlin + Jetpack Compose Android client | Android app |
| **[`ios`](https://github.com/Gapwise-for-UTM/ios)** | Native Swift + SwiftUI iOS client | iOS app |
| **[`ai`](https://github.com/Gapwise-for-UTM/ai)** | OAuth/MCP layer for explicitly delegated student context and bounded actions | [ai.gapwise.ca](https://ai.gapwise.ca) |
| **[`data`](https://github.com/Gapwise-for-UTM/data)** | Canonical public UTM campus data, provenance, schemas, validation, and distribution | [data.gapwise.ca](https://data.gapwise.ca) |
| **[`docs`](https://github.com/Gapwise-for-UTM/docs)** | Canonical public developer documentation | [docs.gapwise.ca](https://docs.gapwise.ca) |
| **[`status`](https://github.com/Gapwise-for-UTM/status)** | Independent service-health monitoring and incident communication | [status.gapwise.ca](https://status.gapwise.ca) |

The repositories are separate implementation and trust boundaries, but they form one product. Native clients should consume canonical Gapwise behavior rather than silently becoming independent timetable, routing, or campus-data engines.

---

## Independent project

> **Gapwise is an independent student software project created by Andrew Muratov. It is not affiliated with, endorsed by, or an official service of the University of Toronto.**

## License

Original project code and documentation are available under the [MIT License](LICENSE).

<div align="center">

**Built for the spaces between classes — coming natively to iOS.**

[Open Gapwise →](https://gapwise.ca)

</div>
