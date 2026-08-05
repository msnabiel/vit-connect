# VIT Connect Code Audit and Fixes

Date: 2026-08-04

This audit covers the SwiftUI review findings from the current worktree. Existing unrelated changes were preserved.

## Fixed issues

### 1. Marks cache was not fully cleared

`marksBySemester.json` and `cumulativeMarksBySemester.json` were omitted when the Marks & Grades cache bucket was disabled. The in-memory semester-scoped dictionaries were also retained.

Fixed in `VTOPDataCache.clearVTOPBucket` and `DataManager.clearInMemoryVTOPFields`.

### 2. Release build number was reset

The app build number had been changed from `3` to `1`, which can prevent App Store uploads because build numbers must increase.

Both app configurations now use build number `4`. The marketing version remains `1.0.4`.

### 3. Class-average calculation could divide by zero

The marks summary now requires both `totalMax > 0` and `totalMaxWeightage > 0` before calculating weighted class averages. This prevents invalid `NaN`/infinite values from reaching the UI.

### 4. User-entered averages were not account-scoped

Saved class averages now include the active register number in their preference key. Averages entered for one account are therefore not displayed for another account on the same device. Course clearing uses the same account-scoped key format.

### 5. Share-sheet presentation could use the wrong scene

The duplicated share-sheet code now uses the active foreground scene, prefers its key window, resolves presented/navigation/tab controllers, and presents from the visible controller.

### 6. Invalid class averages were accepted silently

Empty values still remove a saved average. Non-empty values are saved only when they parse as finite, non-negative numbers; invalid input keeps the editor open instead of silently discarding it.

### 7. Deprecated SwiftUI APIs were migrated

The project’s SwiftUI views now use:

- `NavigationStack` instead of `NavigationView`
- `navigationTitle` plus `navigationBarTitleDisplayMode`
- `foregroundStyle` instead of `foregroundColor`
- `clipShape(.rect(cornerRadius:))` instead of `cornerRadius`
- the no-argument `onChange` form where only the new state was needed

## Verification

- `git diff --check`: passed.
- Repository search found no remaining `NavigationView`, `foregroundColor`, `cornerRadius`, `navigationBarTitle`, `navigationBarItems`, `navigationBarHidden`, or `edgesIgnoringSafeArea` usages in Swift sources.
- The simulator build could not complete because the local CoreSimulator service (`simdiskimaged`) was unavailable. This is an environment failure, not a reported source diagnostic.

## Second-pass fixes

### Lifecycle and memory

- Replaced the direct `WKScriptMessageHandler` registration with a weak proxy and tear down the WebView, delegates, and message handler on sign out.
- Replaced the repeating debug-console `Timer` with a view-scoped cancellable `.task` loop.
- Made `VTOPLogger` protect its mutable log buffer with a lock so WebKit callbacks and UI reads cannot race.
- Disabled file-based debug instrumentation outside Debug builds and moved the Debug file to the app caches directory instead of a developer-specific absolute path.

### Cache performance and correctness

- Coalesced repeated `persistCache()` calls into a delayed generation-based write.
- Serialized snapshot encoding and disk writes on a utility queue so sync responses do not block the main thread.
- Updated cache metadata and peripheral publishing only after persistence completes.
- Added a restore generation check so an older asynchronous cache restore cannot overwrite newer live data.

### SwiftUI correctness and UI

- Added stable UUID identity to profile rows, including backward-compatible decoding of older cached rows.
- Replaced profile and quiz review index-based `ForEach` identity with stable model identity.
- Added async refresh adapters and migrated several pull-to-refresh screens away from repeated continuation boilerplate.
- Replaced the remaining old autocapitalization/autocorrection APIs.
- Migrated the main tab bar from `tabItem` to the iOS 18 `Tab` API.
- Added accessibility labels to image-only share and menu controls.
- Replaced the custom closure-based home-tab environment value with a `Binding<Int>` environment value.
- Removed the unused legacy performance placeholder and card implementation.
- Cached decoded staff portraits in a dedicated view so normal SwiftUI invalidation does not repeatedly construct `UIImage` values.
- Switched logger timestamp formatting to `Date.FormatStyle` instead of allocating a `DateFormatter` for every row/log call.
- Replaced raw response logging with an explicit `vtop_verbose_response_logging` Debug setting.
- Extracted loading, cache metadata, sync quota, and fetch-failure state into `DataManagerSyncState`, so progress changes do not publish through the full academic-data manager.
- Replaced custom fixed-size SwiftUI fonts with a `@ScaledMetric`-backed `vtopFont` modifier, preserving the visual hierarchy while supporting Dynamic Type.
- Migrated positional `Section(header:)` uses to current title or trailing-header initializers.

## Remaining recommended work

`DataManager` still owns the domain data and WebView orchestration, so a future split of session/network orchestration from academic stores could improve testability further. The current high-churn UI state has already been isolated. Remaining validation is runtime profiling on a real device with Instruments for WebView, cache, and image-memory behavior.

## Daily cockpit implementation

- Expanded the app-group snapshot with attendance risk and the next exam so the app, widget, notifications, and Shortcuts share one derived payload.
- Added Home cockpit cards for next class, upcoming exam, attendance insights, and marks overview using Swift Charts with VoiceOver summaries.
- Expanded the widget to support the large family and show today’s schedule when space allows.
- Added `vitconnect://` deep-link routes and App Intents for next class, attendance, and refresh actions.
- Added local notification preferences for class reminders, exam reminders, and attendance warnings; changing a preference immediately reschedules pending requests.
- Added focused tests for risk thresholds, deep-link round trips, and snapshot serialization.

## Personalization implementation

- Added a single personalization store for appearance mode, accent color, dashboard layout, visible cockpit cards, attendance target, and percentage display.
- Added a Profile → Personalization screen with immediate settings updates and accessible controls.
- Added configurable class reminder lead time and quiet hours; notification scheduling now respects the selected attendance target and quiet-hour window.
- Connected the selected appearance and accent color to the app root, including System, Light, and Dark modes.

## Runtime fixes

- Unified the app and widget App Group entitlement on `group.com.msnabiel.vit-connect`, matching the shared snapshot code and removing the app-side entitlement mismatch.
- Removed the UIKit tab reselect delegate from the SwiftUI shell so selecting Marks is handled by the native `TabView` selection path without custom delegate interference.
- Added FlowKit-inspired native settings rows with colored SF Symbol containers to the Profile screen.
- Consolidated Profile navigation into Academic Information, Campus & community, App settings, and About VIT Connect groups to reduce scrolling and duplicated sections.
- Merged related Profile rows into single semantic entries that open focused hubs: Classes, Performance, Learning tools, Student account, Campus & community, App settings, and About. Exam Schedule and Event hub remain separate as requested.
