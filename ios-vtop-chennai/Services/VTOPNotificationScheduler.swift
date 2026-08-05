import Foundation
import UserNotifications
import UIKit

enum VTOPNotificationScheduler {
    private static let requestPrefix = "vtop."

    static func registerDelegate() {
        UNUserNotificationCenter.current().delegate = VTOPNotificationDelegate.shared
    }

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    /// Schedules local notifications before the next upcoming class.
    static func reschedule(
        from snapshot: VTOPGlanceSnapshot,
        timetable: [TimetableSlot],
        courses: [Course],
        exams: [Exam] = [],
        attendance: [Attendance] = []
    ) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingIds())

        if VTOPNotificationPreferences.classRemindersEnabled,
           let start = snapshot.nextClassStart,
           start > Date().addingTimeInterval(60) {
            let title = snapshot.nextClassTitle ?? "Next class"
            let venue = snapshot.nextClassVenue ?? ""
            let minutes = VTOPPersonalizationPreferences.classLeadMinutes
            schedule(
                    id: requestPrefix + "class-\(minutes)",
                    title: "Class in \(minutes) min",
                    body: venue.isEmpty ? title : "\(title) · \(venue)",
                    fireDate: start.addingTimeInterval(Double(-minutes * 60)),
                    route: .timetable
            )
        }

        if VTOPNotificationPreferences.examRemindersEnabled,
           let nextExam = VTOPCockpitMetrics.nextExam(from: exams) {
            for hours in [24, 1] {
                let examTitle = nextExam.0.courseTitle ?? nextExam.0.title
                schedule(
                    id: requestPrefix + "exam-\(hours)",
                    title: hours == 24 ? "Exam tomorrow" : "Exam in 1 hour",
                    body: "\(examTitle) · \(nextExam.1.formatted(date: .abbreviated, time: .shortened))",
                    fireDate: nextExam.1.addingTimeInterval(Double(-hours * 3600)),
                    route: .exams
                )
            }
        }

        if VTOPNotificationPreferences.attendanceWarningsEnabled,
           let percent = snapshot.attendancePercent,
           percent < VTOPPersonalizationPreferences.attendanceThreshold {
            schedule(
                id: requestPrefix + "attendance-warning",
                title: "Attendance needs attention",
                body: "Your latest overall attendance is \(percent)%, below your \(VTOPPersonalizationPreferences.attendanceThreshold)% target.",
                fireDate: Date().addingTimeInterval(60),
                route: .attendance
            )
        }
    }

    private static func schedule(id: String, title: String, body: String, fireDate: Date, route: VTOPDeepLinkRoute) {
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 2 else { return }
        guard !isQuietHour(fireDate) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["route": route.rawValue]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func isQuietHour(_ date: Date) -> Bool {
        guard VTOPPersonalizationPreferences.quietHoursEnabled else { return false }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let start = VTOPPersonalizationPreferences.quietHoursStart.hour ?? 22
        let end = VTOPPersonalizationPreferences.quietHoursEnd.hour ?? 7
        if start == end { return true }
        if start < end { return hour >= start && hour < end }
        return hour >= start || hour < end
    }

    private static func pendingIds() -> [String] {
        [
            requestPrefix + "class-30",
            requestPrefix + "class-15",
            requestPrefix + "exam-24",
            requestPrefix + "exam-1",
            requestPrefix + "attendance-warning"
        ]
    }
}

final class VTOPNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = VTOPNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let rawRoute = response.notification.request.content.userInfo["route"] as? String,
           let route = VTOPDeepLinkRoute(rawValue: rawRoute) {
            DispatchQueue.main.async {
                UIApplication.shared.open(route.url)
            }
        }
        completionHandler()
    }
}
