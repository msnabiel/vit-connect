# VIT Connect

VIT Connect is an iOS app for viewing VTOP academic information in one place. It provides a daily overview, attendance and marks, timetable and exams, student profile tools, and a glance widget.

[Download VIT Connect on the App Store](https://apps.apple.com/in/app/vit-connect/id6764813035)

## Requirements

- A Mac with Xcode and an iOS 18.2 or newer SDK
- An iOS 18.2 or newer device or simulator
- VTOP credentials for live academic data

## Run locally

1. Open `ios-vtop-chennai.xcodeproj` in Xcode.
2. Select the **VIT Connect** scheme and an iOS device or simulator.
3. Configure a development team under Signing & Capabilities if running on a physical device.
4. Build and run, then sign in with your VTOP account.

From the command line, list available destinations with:

```sh
xcodebuild -project ios-vtop-chennai.xcodeproj -scheme "VIT Connect" -showdestinations
```

To run the unit and UI test targets, use the **VIT Connect** scheme's Test action in Xcode with an available simulator.

## Features

- Home overview with today's classes, upcoming exams, attendance, marks, and sync status
- Attendance and marks views with semester selection and detailed course information
- Timetable, exam schedule, academic search, and grade planning
- Notes, to-dos, games, and student profile tools
- Home Screen widget, Live Activity, local reminders, and App Shortcuts
- Optional biometric app lock and personalization settings

VTOP sign-in uses WebKit. Saved credentials use Keychain; academic snapshots are cached locally for offline access. The app includes a SwiftData store alongside its existing JSON cache during migration.

## Repository layout

| Path | Purpose |
| --- | --- |
| `ios-vtop-chennai/` | App views, models, services, persistence, and assets |
| `VTOPGlanceWidgetExtension/` | Widget and Live Activity UI |
| `Shared/` | Types shared by the app and extension |
| `ios-vtop-chennaiTests/` | Unit tests |
| `ios-vtop-chennaiUITests/` | UI tests |
| `docs/` | Plans, audit notes, and migration notes |

## Project notes

- [Academic UI upgrade plan](docs/ACADEMIC_UI_UPGRADE_PLAN.md)
- [Code audit and fixes](docs/CODE_AUDIT_FIXES.md)
- [Home UX feature notes](docs/HOME_UX_FEATURE_TODO.md)
- [SwiftData migration plan](docs/SWIFTDATA_MIGRATION.md)
