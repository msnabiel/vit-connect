import SwiftUI

enum VTOPPersonalizationPreferences {
    static let appearanceKey = "vtop_personalization_appearance"
    static let accentKey = "vtop_personalization_accent"
    static let dashboardLayoutKey = "vtop_personalization_dashboard_layout"
    static let visibleCardsKey = "vtop_personalization_visible_cards"
    static let attendanceThresholdKey = "vtop_personalization_attendance_threshold"
    static let showPercentagesKey = "vtop_personalization_show_percentages"
    static let quietHoursEnabledKey = "vtop_notifications_quiet_hours_enabled"
    static let quietHoursStartKey = "vtop_notifications_quiet_hours_start"
    static let quietHoursEndKey = "vtop_notifications_quiet_hours_end"
    static let classLeadMinutesKey = "vtop_notifications_class_lead_minutes"
    static let appLockEnabledKey = "vtop_privacy_app_lock_enabled"

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: Self { self }
        var title: String { rawValue.capitalized }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    enum Accent: String, CaseIterable, Identifiable {
        case blue, indigo, purple, teal, green, orange, pink
        var id: Self { self }
        var title: String { rawValue.capitalized }
        var color: Color {
            switch self {
            case .blue: .blue
            case .indigo: .indigo
            case .purple: .purple
            case .teal: .teal
            case .green: .green
            case .orange: .orange
            case .pink: .pink
            }
        }
    }

    enum DashboardLayout: String, CaseIterable, Identifiable {
        case standard, compact, detailed
        var id: Self { self }
        var title: String { rawValue.capitalized }
        var spacing: CGFloat {
            switch self {
            case .compact: 12
            case .standard: 20
            case .detailed: 24
            }
        }
    }

    enum DashboardCard: String, CaseIterable, Identifiable {
        case nextClass, exams, attendance, marks
        var id: Self { self }
        var title: String {
            switch self {
            case .nextClass: "Next class"
            case .exams: "Upcoming exams"
            case .attendance: "Attendance insights"
            case .marks: "Marks insights"
            }
        }
        var symbol: String {
            switch self {
            case .nextClass: "calendar"
            case .exams: "calendar.badge.exclamationmark"
            case .attendance: "chart.bar.xaxis"
            case .marks: "chart.line.uptrend.xyaxis"
            }
        }
    }

    static var appearance: Appearance {
        get { Appearance(rawValue: UserDefaults.standard.string(forKey: appearanceKey) ?? "system") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: appearanceKey) }
    }

    static var accent: Accent {
        get { Accent(rawValue: UserDefaults.standard.string(forKey: accentKey) ?? "blue") ?? .blue }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: accentKey) }
    }

    static var dashboardLayout: DashboardLayout {
        get { DashboardLayout(rawValue: UserDefaults.standard.string(forKey: dashboardLayoutKey) ?? "standard") ?? .standard }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: dashboardLayoutKey) }
    }

    static var visibleCards: Set<DashboardCard> {
        get {
            let raw = (UserDefaults.standard.string(forKey: visibleCardsKey) ?? DashboardCard.allCases.map(\.rawValue).joined(separator: ",")).split(separator: ",").map(String.init)
            return Set(raw.compactMap(DashboardCard.init(rawValue:)))
        }
        set { UserDefaults.standard.set(newValue.map(\.rawValue).joined(separator: ","), forKey: visibleCardsKey) }
    }

    static var attendanceThreshold: Int {
        get {
            let value = UserDefaults.standard.object(forKey: attendanceThresholdKey) as? Int ?? 75
            return min(max(value, 50), 100)
        }
        set { UserDefaults.standard.set(min(max(newValue, 50), 100), forKey: attendanceThresholdKey) }
    }

    static var showPercentages: Bool {
        get { UserDefaults.standard.object(forKey: showPercentagesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showPercentagesKey) }
    }

    static var quietHoursEnabled: Bool { UserDefaults.standard.bool(forKey: quietHoursEnabledKey) }
    static var quietHoursStart: DateComponents {
        get { DateComponents(hour: UserDefaults.standard.object(forKey: quietHoursStartKey) as? Int ?? 22, minute: 0) }
        set { UserDefaults.standard.set(newValue.hour ?? 22, forKey: quietHoursStartKey) }
    }
    static var quietHoursEnd: DateComponents {
        get { DateComponents(hour: UserDefaults.standard.object(forKey: quietHoursEndKey) as? Int ?? 7, minute: 0) }
        set { UserDefaults.standard.set(newValue.hour ?? 7, forKey: quietHoursEndKey) }
    }
    static var classLeadMinutes: Int {
        get { UserDefaults.standard.object(forKey: classLeadMinutesKey) as? Int ?? 15 }
        set { UserDefaults.standard.set(newValue, forKey: classLeadMinutesKey) }
    }
}
