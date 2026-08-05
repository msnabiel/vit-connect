import Foundation

enum VTOPNotificationPreferences {
    static let classRemindersKey = "vtop_notifications_class_reminders"
    static let examRemindersKey = "vtop_notifications_exam_reminders"
    static let attendanceWarningsKey = "vtop_notifications_attendance_warnings"

    static var classRemindersEnabled: Bool {
        UserDefaults.standard.object(forKey: classRemindersKey) as? Bool ?? true
    }

    static var examRemindersEnabled: Bool {
        UserDefaults.standard.bool(forKey: examRemindersKey)
    }

    static var attendanceWarningsEnabled: Bool {
        UserDefaults.standard.bool(forKey: attendanceWarningsKey)
    }
}
