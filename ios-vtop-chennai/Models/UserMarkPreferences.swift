import Foundation

/// User-entered preferences for marks, such as class averages for individual assessments.
struct UserMarkPreferences {
    private static let userDefaultsKey = "user_mark_preferences"

    /// Retrieve user-entered class average for a specific assessment.
    /// - Parameters:
    ///   - courseCode: The course code (e.g., "CSE1001")
    ///   - markTitle: The assessment title (e.g., "CAT1", "CAT2")
    /// - Returns: The user-entered class average, or nil if not set
    static func getClassAverage(courseCode: String, markTitle: String) -> Double? {
        let key = makeKey(courseCode: courseCode, markTitle: markTitle)
        let prefs = loadPreferences()
        return prefs[key]
    }

    /// Save user-entered class average for a specific assessment.
    /// - Parameters:
    ///   - courseCode: The course code
    ///   - markTitle: The assessment title
    ///   - average: The class average to save (pass nil to remove)
    static func setClassAverage(courseCode: String, markTitle: String, average: Double?) {
        let key = makeKey(courseCode: courseCode, markTitle: markTitle)
        var prefs = loadPreferences()

        if let avg = average {
            prefs[key] = avg
        } else {
            prefs.removeValue(forKey: key)
        }

        savePreferences(prefs)
    }

    /// Clear all user-entered class averages for a specific course.
    static func clearCourse(courseCode: String) {
        var prefs = loadPreferences()
        let account = AppCacheSettings.activeRegisterNumber() ?? "shared"
        let coursePrefix = "\(account)\u{1F}\(courseCode)\u{1F}"
        let keysToRemove = prefs.keys.filter { $0.hasPrefix(coursePrefix) }
        for key in keysToRemove {
            prefs.removeValue(forKey: key)
        }
        savePreferences(prefs)
    }

    /// Clear all user preferences.
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    // MARK: - Private Helpers

    private static func makeKey(courseCode: String, markTitle: String) -> String {
        let account = AppCacheSettings.activeRegisterNumber() ?? "shared"
        return "\(account)\u{1F}\(courseCode)\u{1F}\(markTitle)"
    }

    private static func loadPreferences() -> [String: Double] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let prefs = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return prefs
    }

    private static func savePreferences(_ prefs: [String: Double]) {
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
