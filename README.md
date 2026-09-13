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

The repository contains a working early native application: an iPhone SwiftUI target, on-device `.ics` timetable import with a review-before-save flow, local timetable persistence, campus-qualified schedule models, date-aware Today and Timetable views, an honest UTM-first Campus boundary, Settings, portable domain tests, and macOS CI configuration.

This remains an **early implementation**, not a shipped client. Import compatibility has been validated against synthetic standards-based fixtures, not every calendar producer or a live ACORN export. Timetable editing, gaps, maps, routing, account continuity, and remote integrations are still planned work. The preview schedule is development-only and the production app starts with an empty local timetable.

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

## App surface

The current foundation includes:

- **Today**, derived from local timetable data, with current/next-class context and empty states;
- **Timetable**, with week/day navigation and campus-aware meeting cards;
- **Campus**, with a selectable campus context and an explicit UTM-first availability state;
- **Settings**, with appearance, local timetable removal, campus context, privacy, version, and ecosystem links;
- a native document-picker and import preview for compatible `.ics` timetable/calendar exports;
- atomic local JSON persistence behind an async repository boundary;
- light/dark appearance, Dynamic Type-friendly layouts, VoiceOver labels, and native navigation.

The native iOS client is intended to grow toward the remaining Gapwise experience:

- broader timetable-import compatibility and user-controlled editing;
- **Gaps** for deterministic time-between-class planning;
- **Map** for UTM-focused campus navigation and route context;
- timetable editing, exports, and integrations;
- optional, explicitly scoped account continuity.

These are roadmap targets. This README will be tightened as implementation lands so the “current” surface never outruns the code.

---

## Technology

Gapwise for iOS uses modern native Apple tooling:

- **Swift**
- **SwiftUI**
- Foundation persistence and Apple lifecycle APIs
- **Keychain / platform-secure storage** where secret material is eventually required
- a native map stack compatible with canonical Gapwise UTM data and routing semantics
- optional Gapwise account integration only after its security boundary is implemented and reviewed

The architecture keeps portable domain models, iCalendar parsing, schedule interpretation, reconciliation, and schedule arithmetic separate from persistence and SwiftUI features. Account/sync and map integration will remain separate boundaries as they are introduced.

### Timetable import

Gapwise accepts user-selected `.ics` files through the system document picker. Parsing, interpretation, preview, and persistence happen locally. The original calendar file is not copied into the app container and timetable contents are not uploaded.

The current parser intentionally supports the timetable-oriented iCalendar subset used by the app: `VCALENDAR`, `VEVENT`, `DTSTART`, `DTEND`, `SUMMARY`, `LOCATION`, `DESCRIPTION`, `UID`, bounded weekly `RRULE` values, folded lines, escaped text, UTF-8 input, and UTC, numeric-offset, `America/Toronto`, or floating timestamps. Floating times are interpreted in Toronto time and surfaced as review warnings.

Course meetings are imported only when a full U of T-style course code and meeting section can be identified. Campus remains explicit in the model: calendar/event wording can identify UTM, UTSG, or UTSC, and a small centralized mapping of published UTM building codes can provide UTM evidence. Conflicting or insufficient evidence produces `unknown`, never a course-code guess.

Repeated imports reconcile by calendar-source identity and event `UID`. Existing matches are updated, unchanged events are not duplicated, and entries from other imports or future manual sources remain untouched. A meeting missing from a newer export is conservatively retained until Gapwise has an explicit removal review.

Current limitations:

- recurring events must be weekly, use an interval of one, and be bounded by `COUNT` or `UNTIL`;
- recurrence exceptions (`EXDATE`, `RDATE`, and `RECURRENCE-ID`) and non-weekly recurrence are reported and skipped;
- timezone identifiers other than recognized system zones and `America/Toronto` aliases are not guessed;
- campus/building recognition is intentionally incomplete, with UTM as the initial building-code focus;
- importing is not ACORN login, credential access, scraping, or an account/API integration;
- imported meetings can be reviewed and the whole saved timetable can be removed, but individual editing is not implemented yet.

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

The current timetable store writes an atomically replaced JSON snapshot inside Application Support and applies iOS file protection. Calendar import is performed on-device without networking, telemetry, or retention of the source file. No account sync, end-to-end encryption, analytics, or map capability is implemented.

---

## Development

The app targets iPhone on iOS 17 or later and uses a filesystem-synchronized Xcode 16 project. There are no third-party runtime dependencies.

```bash
git clone https://github.com/Gapwise-for-UTM/ios.git
cd ios
```

Open `Gapwise.xcodeproj` in Xcode 16 or later, select the `Gapwise` scheme, and run it on an iPhone simulator or device. The shared scheme builds the app and runs `GapwiseTests`.

The Foundation-only core, import pipeline, and tests also build on Linux:

```bash
swift test
```

GitHub Actions runs those portable tests on Ubuntu and runs the complete unsigned iOS build and unit-test suite on a dynamically selected iPhone simulator on `macos-15`.

Linux cannot compile or exercise SwiftUI, the document picker, Apple security-scoped URL behavior, or the iOS app target. Those remain Xcode/macOS validation responsibilities; Linux coverage is limited to the portable Foundation core and fixture-driven tests.

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
