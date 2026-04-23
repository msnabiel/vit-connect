import Foundation

/// User-controlled flags for what is allowed to persist on disk / restore at launch.
enum AppCacheSettings {
    private static let activeRegisterNumberKey = "cache_active_register_number"
    private static let clearCacheOnSignOutKey = "cache_clear_on_sign_out"

    private static func isOn(_ key: String, default defaultOn: Bool = true) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return defaultOn }
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func setOn(_ key: String, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: key)
    }

    private static func normalizedRegisterNumber(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let filtered = trimmed
            .uppercased()
            .map { ch in ch.isLetter || ch.isNumber || ch == "-" || ch == "_" ? ch : "_" }
        return String(filtered)
    }

    static func activeRegisterNumber() -> String? {
        normalizedRegisterNumber(UserDefaults.standard.string(forKey: activeRegisterNumberKey))
    }

    static func setActiveRegisterNumber(_ value: String?) {
        guard let normalized = normalizedRegisterNumber(value) else {
            UserDefaults.standard.removeObject(forKey: activeRegisterNumberKey)
            return
        }
        UserDefaults.standard.set(normalized, forKey: activeRegisterNumberKey)
    }

    static func clearCacheOnSignOutEnabled() -> Bool {
        isOn(clearCacheOnSignOutKey, default: false)
    }

    static func setClearCacheOnSignOutEnabled(_ enabled: Bool) {
        setOn(clearCacheOnSignOutKey, enabled)
    }

    // MARK: - VTOP snapshot buckets

    enum VTOPBucket: String, CaseIterable, Identifiable {
        case profileSummary
        case academic
        case marksAndGrades
        case exams
        case receipts
        case campusExtras

        var id: String { rawValue }

        var storageKey: String { "cache_vtop_bucket_\(rawValue)" }

        var title: String {
            switch self {
            case .profileSummary: return "Profile summary"
            case .academic: return "Courses, timetable & attendance"
            case .marksAndGrades: return "Marks & grade history"
            case .exams: return "Exams & exam schedule"
            case .receipts: return "Payment receipts"
            case .campusExtras: return "Staff, events & portal extras"
            }
        }

        static func isEnabled(_ bucket: VTOPBucket) -> Bool {
            isOn(bucket.storageKey)
        }

        static func setEnabled(_ bucket: VTOPBucket, _ enabled: Bool) {
            setOn(bucket.storageKey, enabled)
        }
    }

    // MARK: - Local-only stores

    enum UserStore: String, CaseIterable, Identifiable {
        case friendsImports
        case notesAndTodos

        var id: String { rawValue }

        var storageKey: String { "cache_user_store_\(rawValue)" }

        var title: String {
            switch self {
            case .friendsImports: return "Friends timetable imports"
            case .notesAndTodos: return "Notes & To‑Do"
            }
        }

        static func isEnabled(_ store: UserStore) -> Bool {
            isOn(store.storageKey)
        }

        static func setEnabled(_ store: UserStore, _ enabled: Bool) {
            setOn(store.storageKey, enabled)
        }
    }
}
