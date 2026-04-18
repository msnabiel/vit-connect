import Foundation

struct Exam: Codable, Identifiable, Hashable {
    let id: Int
    let courseId: Int
    /// Exam segment from schedule (e.g. FAT, CAT1) or legacy label.
    var title: String
    var startTime: Int64?  // Timestamp
    var endTime: Int64?    // Timestamp
    var venue: String?
    var seatLocation: String?
    var seatNumber: Int?

    var courseCode: String?
    var courseTitle: String?
    var examCategory: String?
    var examDateText: String?
    var sessionLabel: String?
    var reportingTimeText: String?
    var examTimeRangeText: String?
    var slotText: String?
    var classIdText: String?
    var courseTypeAbbrev: String?

    init(
        id: Int,
        courseId: Int,
        title: String,
        startTime: Int64? = nil,
        endTime: Int64? = nil,
        venue: String? = nil,
        seatLocation: String? = nil,
        seatNumber: Int? = nil,
        courseCode: String? = nil,
        courseTitle: String? = nil,
        examCategory: String? = nil,
        examDateText: String? = nil,
        sessionLabel: String? = nil,
        reportingTimeText: String? = nil,
        examTimeRangeText: String? = nil,
        slotText: String? = nil,
        classIdText: String? = nil,
        courseTypeAbbrev: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.venue = venue
        self.seatLocation = seatLocation
        self.seatNumber = seatNumber
        self.courseCode = courseCode
        self.courseTitle = courseTitle
        self.examCategory = examCategory
        self.examDateText = examDateText
        self.sessionLabel = sessionLabel
        self.reportingTimeText = reportingTimeText
        self.examTimeRangeText = examTimeRangeText
        self.slotText = slotText
        self.classIdText = classIdText
        self.courseTypeAbbrev = courseTypeAbbrev
    }

    var startDate: Date? {
        guard let timestamp = startTime else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
    }

    var endDate: Date? {
        guard let timestamp = endTime else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
    }

    var formattedStartTime: String? {
        guard let date = startDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, h:mm a"
        return formatter.string(from: date)
    }

    var formattedEndTime: String? {
        guard let date = endDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Exam, rhs: Exam) -> Bool {
        lhs.id == rhs.id
    }

    /// Timetable/catalog row when codes align (same idea as attendance).
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
}
