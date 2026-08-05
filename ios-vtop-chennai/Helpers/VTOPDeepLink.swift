import Foundation

enum VTOPDeepLinkRoute: String, CaseIterable, Equatable, Sendable {
    case home
    case timetable
    case attendance
    case marks
    case exams
    case events

    static let scheme = "vitconnect"

    var url: URL {
        URL(string: "\(Self.scheme)://\(rawValue)")!
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let host = url.host?.lowercased(),
              let route = Self(rawValue: host) else { return nil }
        self = route
    }

    var tabIndex: Int {
        switch self {
        case .home: return 0
        case .attendance: return 1
        case .marks: return 2
        case .timetable, .exams, .events: return 3
        }
    }
}
