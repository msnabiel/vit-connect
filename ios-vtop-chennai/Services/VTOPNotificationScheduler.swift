import Foundation
import UserNotifications

enum VTOPNotificationScheduler {
    private static let requestPrefix = "vtop.nextclass."

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
    static func reschedule(from snapshot: VTOPGlanceSnapshot, timetable: [TimetableSlot], courses: [Course]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingIds())

        guard let start = snapshot.nextClassStart, start > Date().addingTimeInterval(60) else { return }

        let title = snapshot.nextClassTitle ?? "Next class"
        let venue = snapshot.nextClassVenue ?? ""

        for minutes in [30, 15] {
            let fireDate = start.addingTimeInterval(Double(-minutes * 60))
            let interval = fireDate.timeIntervalSinceNow
            guard interval > 2 else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Class in \(minutes) min"
            content.body = venue.isEmpty ? title : "\(title) · \(venue)"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let id = requestPrefix + "\(minutes)"
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            )
        }
    }

    private static func pendingIds() -> [String] {
        [requestPrefix + "30", requestPrefix + "15"]
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
}
