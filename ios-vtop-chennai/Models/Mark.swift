import Foundation

struct Mark: Codable, Identifiable, Hashable {
    let id: Int
    let courseId: Int
    var title: String
    var score: Double
    var maxScore: Double?
    var weightage: Double
    var maxWeightage: Double?
    var average: Double?
    var status: String
    var isRead: Bool
    var signature: Int

    init(id: Int, courseId: Int, title: String, score: Double, maxScore: Double? = nil,
         weightage: Double, maxWeightage: Double? = nil, average: Double? = nil,
         status: String, isRead: Bool = false, signature: Int) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.score = score
        self.maxScore = maxScore
        self.weightage = weightage
        self.maxWeightage = maxWeightage
        self.average = average
        self.status = status
        self.isRead = isRead
        self.signature = signature
    }

    var scorePercentage: Double? {
        guard let maxScore = maxScore, maxScore > 0 else { return nil }
        return (score / maxScore) * 100
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Mark, rhs: Mark) -> Bool {
        lhs.id == rhs.id
    }
}

struct CumulativeMark: Codable, Identifiable, Hashable {
    let id: Int
    var courseCode: String
    var theoryTotal: Double?
    var theoryMax: Double?
    var labTotal: Double?
    var labMax: Double?
    var projectTotal: Double?
    var projectMax: Double?
    var grandTotal: Double?
    var grandMax: Double?
    var grade: String?

    init(id: Int, courseCode: String, theoryTotal: Double? = nil, theoryMax: Double? = nil,
         labTotal: Double? = nil, labMax: Double? = nil, projectTotal: Double? = nil,
         projectMax: Double? = nil, grandTotal: Double? = nil, grandMax: Double? = nil,
         grade: String? = nil) {
        self.id = id
        self.courseCode = courseCode
        self.theoryTotal = theoryTotal
        self.theoryMax = theoryMax
        self.labTotal = labTotal
        self.labMax = labMax
        self.projectTotal = projectTotal
        self.projectMax = projectMax
        self.grandTotal = grandTotal
        self.grandMax = grandMax
        self.grade = grade
    }

    var totalPercentage: Double? {
        guard let total = grandTotal, let max = grandMax, max > 0 else { return nil }
        return (total / max) * 100
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CumulativeMark, rhs: CumulativeMark) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Marks report (doStudentMarkView by semester — separate from timetable `marks`)

struct MarkReportRow: Codable, Identifiable, Hashable {
    let id: Int
    let courseCode: String
    let courseTitle: String?
    let markTitle: String
    let maxMark: Double
    let weightagePercent: Double
    let scoredMark: Double
    let weightageMark: Double
    let status: String
    let classAverage: Double?
}
