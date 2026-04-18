import Foundation

struct Attendance: Codable, Identifiable, Hashable {
    let id: Int
    let courseId: Int
    var attended: Int
    var total: Int
    var percentage: Int
    /// From `processViewStudentAttendance` when available.
    var courseCode: String?
    var courseTitle: String?
    var courseType: String?
    var slot: String?
    var facultySummary: String?
    var attendanceType: String?
    var registrationDateText: String?
    var attendanceDateText: String?
    var statusText: String?

    init(
        id: Int,
        courseId: Int,
        attended: Int,
        total: Int,
        percentage: Int,
        courseCode: String? = nil,
        courseTitle: String? = nil,
        courseType: String? = nil,
        slot: String? = nil,
        facultySummary: String? = nil,
        attendanceType: String? = nil,
        registrationDateText: String? = nil,
        attendanceDateText: String? = nil,
        statusText: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.attended = attended
        self.total = total
        self.percentage = percentage
        self.courseCode = courseCode
        self.courseTitle = courseTitle
        self.courseType = courseType
        self.slot = slot
        self.facultySummary = facultySummary
        self.attendanceType = attendanceType
        self.registrationDateText = registrationDateText
        self.attendanceDateText = attendanceDateText
        self.statusText = statusText
    }

    var attendanceRatio: String {
        return "\(attended)/\(total)"
    }

    /// Catalog row for this attendance: match **course code** first (authoritative vs timetable), then `courseId` if non-zero.
    func matchingCatalogCourse(in courses: [Course]) -> Course? {
        let ac = (courseCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !ac.isEmpty {
            if let c = courses.first(where: {
                $0.code.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(ac) == .orderedSame
            }) {
                return c
            }
        }
        if courseId != 0, let c = courses.first(where: { $0.id == courseId }) {
            return c
        }
        return nil
    }

    var attendanceColor: AttendanceStatus {
        if percentage >= 75 {
            return .good
        } else if percentage >= 65 {
            return .warning
        } else {
            return .danger
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Attendance, rhs: Attendance) -> Bool {
        lhs.id == rhs.id
    }
}

enum AttendanceStatus {
    case good
    case warning
    case danger
}
