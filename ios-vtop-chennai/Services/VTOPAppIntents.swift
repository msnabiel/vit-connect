import AppIntents
import Foundation

extension Notification.Name {
    static let vtopRefreshRequested = Notification.Name("vtop.refresh.requested")
}

private enum VTOPIntentSupport {
    static func open(_ route: VTOPDeepLinkRoute) -> OpenURLIntent {
        OpenURLIntent(route.url)
    }

    static func snapshot() -> VTOPGlanceSnapshot? {
        VTOPGlanceSnapshot.loadShared()
    }
}

struct VTOPNextClassIntent: AppIntent {
    static let title: LocalizedStringResource = "What's My Next Class?"
    static let description = IntentDescription("Shows the next scheduled class from the last VTOP sync.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        let title = VTOPIntentSupport.snapshot()?.nextClassTitle ?? "No upcoming class found"
        return .result(
            opensIntent: VTOPIntentSupport.open(.timetable),
            dialog: IntentDialog(stringLiteral: title)
        )
    }
}

struct VTOPAttendanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Show My Attendance"
    static let description = IntentDescription("Shows your latest attendance percentage and opens Attendance.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        let snapshot = VTOPIntentSupport.snapshot()
        let dialog: IntentDialog
        if let percent = snapshot?.attendancePercent {
            let status = snapshot?.attendanceRiskLabel.map { " (\($0))" } ?? ""
            dialog = IntentDialog(stringLiteral: "Attendance is \(percent)%\(status)")
        } else {
            dialog = IntentDialog(stringLiteral: "Attendance is not available until the app syncs.")
        }
        return .result(opensIntent: VTOPIntentSupport.open(.attendance), dialog: dialog)
    }
}

struct VTOPRefreshIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh VTOP Data"
    static let description = IntentDescription("Opens VIT Connect so the latest VTOP data can be refreshed.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        NotificationCenter.default.post(name: .vtopRefreshRequested, object: nil)
        return .result(opensIntent: VTOPIntentSupport.open(.home), dialog: IntentDialog(stringLiteral: "Opening VIT Connect to refresh your data."))
    }
}

struct VTOPAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
                intent: VTOPNextClassIntent(),
                phrases: ["What's my next class in \(.applicationName)"],
                shortTitle: "Next class",
                systemImageName: "calendar"
            )
            AppShortcut(
                intent: VTOPAttendanceIntent(),
                phrases: ["Show my attendance in \(.applicationName)"],
                shortTitle: "Attendance",
                systemImageName: "chart.bar"
            )
            AppShortcut(
                intent: VTOPRefreshIntent(),
                phrases: ["Refresh \(.applicationName)"],
                shortTitle: "Refresh VTOP",
                systemImageName: "arrow.clockwise"
            )
    }
}
