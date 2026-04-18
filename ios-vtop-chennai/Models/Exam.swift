import Foundation

struct Exam: Codable, Identifiable, Hashable {
    let id: Int
    let courseId: Int
    var title: String
    var startTime: Int64?  // Timestamp
    var endTime: Int64?    // Timestamp
    var venue: String?
    var seatLocation: String?
    var seatNumber: Int?

    init(id: Int, courseId: Int, title: String, startTime: Int64? = nil,
         endTime: Int64? = nil, venue: String? = nil, seatLocation: String? = nil,
         seatNumber: Int? = nil) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.venue = venue
        self.seatLocation = seatLocation
        self.seatNumber = seatNumber
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
}
