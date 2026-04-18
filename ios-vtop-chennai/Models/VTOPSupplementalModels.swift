import Foundation

// MARK: - Profile (accordion-style sections from StudentProfileAllView)

struct ProfileKeyValueRow: Codable, Hashable {
    let key: String
    let value: String
}

struct ProfileAccordionSectionData: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let rows: [ProfileKeyValueRow]

    init(title: String, rows: [ProfileKeyValueRow]) {
        self.id = UUID()
        self.title = title
        self.rows = rows
    }
}

// MARK: - Grade history (StudentGradeHistory — all semesters)

struct GradeHistoryCourseRow: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let sectionTitle: String
    let courseCode: String
    let courseTitle: String?
    let credits: Double?
    let grade: String
}

// MARK: - Portal credentials (viewStudentCredentials)

struct VTOPPortalCredential: Codable, Hashable, Identifiable {
    let id: Int
    let account: String
    let userName: String
    let defaultPassword: String
    let urlString: String?
    let venueDate: String?
    let seatLocation: String?
}

struct VTOPRankEntry: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let rank: String

    init(name: String, rank: String) {
        self.id = UUID()
        self.name = name
        self.rank = rank
    }
}
