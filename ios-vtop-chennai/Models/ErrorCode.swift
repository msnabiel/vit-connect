import Foundation

enum ErrorCode: Int {
    // Connection Errors (100-199)
    case serverConnectionTimeout = 101
    case failedToFetchCredentials = 102
    case captchaImageParsingError = 103
    case captchaTypeParsingError = 104
    case captchaExecutionError = 105
    case loginAttemptParsingError = 106
    case unauthorizedUserAgent = 107

    // Authentication Errors (200-299)
    case semesterParsingError = 201
    case semesterSelectionError = 202

    // Profile Errors (300-399)
    case profileDataParsingError = 301
    case profileFetchError = 302

    // Course Errors (400-499)
    case courseParsingError = 401
    case courseFetchError = 402

    // Exam Errors (500-599)
    case examParsingError = 501
    case examFetchError = 502

    // Marks Errors (600-699)
    case marksParsingError = 601
    case marksFetchError = 602

    // Attendance Errors (700-799)
    case attendanceParsingError = 701
    case attendanceFetchError = 702

    // Timetable Errors (800-899)
    case timetableParsingError = 801
    case timetableFetchError = 802

    // Receipt Errors (900-999)
    case receiptParsingError = 901
    case receiptFetchError = 902

    // Staff Errors (1000-1099)
    case staffParsingError = 1001
    case staffFetchError = 1002
    case staffDetailParsingError = 1003
    case staffDetailFetchError = 1004

    // Spotlight Errors (1100-1199)
    case spotlightParsingError = 1101
    case spotlightFetchError = 1102

    // Sync Errors (1200-1299)
    case syncGeneralError = 1201
    case syncDataParsingError = 1202
    case syncCompleteError = 1203

    var description: String {
        switch self {
        // Connection Errors
        case .serverConnectionTimeout:
            return "Couldn't connect to the server."
        case .failedToFetchCredentials:
            return "Failed to fetch credentials from Keychain."
        case .captchaImageParsingError:
            return "Failed to parse captcha image."
        case .captchaTypeParsingError:
            return "Failed to detect captcha type."
        case .captchaExecutionError:
            return "Failed to execute captcha verification."
        case .loginAttemptParsingError:
            return "Failed to parse login response."
        case .unauthorizedUserAgent:
            return "Unauthorized user agent detected. Updating..."

        // Authentication Errors
        case .semesterParsingError:
            return "Failed to parse semester list."
        case .semesterSelectionError:
            return "Failed to select semester."

        // Profile Errors
        case .profileDataParsingError:
            return "Failed to parse profile data."
        case .profileFetchError:
            return "Failed to fetch profile information."

        // Course Errors
        case .courseParsingError:
            return "Failed to parse course data."
        case .courseFetchError:
            return "Failed to fetch courses."

        // Exam Errors
        case .examParsingError:
            return "Failed to parse exam data."
        case .examFetchError:
            return "Failed to fetch exam schedule."

        // Marks Errors
        case .marksParsingError:
            return "Failed to parse marks data."
        case .marksFetchError:
            return "Failed to fetch marks."

        // Attendance Errors
        case .attendanceParsingError:
            return "Failed to parse attendance data."
        case .attendanceFetchError:
            return "Failed to fetch attendance."

        // Timetable Errors
        case .timetableParsingError:
            return "Failed to parse timetable data."
        case .timetableFetchError:
            return "Failed to fetch timetable."

        // Receipt Errors
        case .receiptParsingError:
            return "Failed to parse receipt data."
        case .receiptFetchError:
            return "Failed to fetch receipts."

        // Staff Errors
        case .staffParsingError:
            return "Failed to parse staff data."
        case .staffFetchError:
            return "Failed to fetch staff information."
        case .staffDetailParsingError:
            return "Failed to parse staff details."
        case .staffDetailFetchError:
            return "Failed to fetch staff details."

        // Spotlight Errors
        case .spotlightParsingError:
            return "Failed to parse spotlight data."
        case .spotlightFetchError:
            return "Failed to fetch spotlight information."

        // Sync Errors
        case .syncGeneralError:
            return "General sync error occurred."
        case .syncDataParsingError:
            return "Failed to parse sync data."
        case .syncCompleteError:
            return "Failed to complete synchronization."
        }
    }
}

// MARK: - Logger Class
class VTOPLogger {
    static let shared = VTOPLogger()

    private var logs: [LogEntry] = []
    private let maxLogs = 1000

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
        let context: String
        let errorCode: Int?

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }

        var emoji: String {
            switch level {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .success: return "✅"
            }
        }
    }

    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case success = "SUCCESS"
    }

    private init() {}

    func log(_ message: String, level: LogLevel = .info, context: String = "", errorCode: Int? = nil) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message, context: context, errorCode: errorCode)
        logs.append(entry)

        // Keep only last maxLogs entries
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }

        // Print to console
        let prefix = entry.emoji
        let codeString = errorCode.map { " [Code: \($0)]" } ?? ""
        let contextString = context.isEmpty ? "" : " [\(context)]"
        print("\(prefix) \(entry.formattedTimestamp)\(contextString)\(codeString): \(message)")
    }

    func debug(_ message: String, context: String = "") {
        log(message, level: .debug, context: context)
    }

    func info(_ message: String, context: String = "") {
        log(message, level: .info, context: context)
    }

    func warning(_ message: String, context: String = "") {
        log(message, level: .warning, context: context)
    }

    func error(_ message: String, context: String = "", code: ErrorCode? = nil) {
        log(message, level: .error, context: context, errorCode: code?.rawValue)
    }

    func success(_ message: String, context: String = "") {
        log(message, level: .success, context: context)
    }

    func getAllLogs() -> [LogEntry] {
        return logs
    }

    func clearLogs() {
        logs.removeAll()
    }
}
