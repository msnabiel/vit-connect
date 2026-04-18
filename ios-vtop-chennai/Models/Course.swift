import Foundation

enum CourseType: String, Codable {
    case lab = "LAB"
    case theory = "THEORY"
    case project = "PROJECT"
}

struct Slot: Codable, Identifiable, Hashable {
    let id: Int
    let slot: String
    let courseId: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Slot, rhs: Slot) -> Bool {
        lhs.id == rhs.id
    }
}

struct Course: Codable, Identifiable, Hashable {
    let id: Int
    var code: String
    var title: String
    var type: CourseType
    var credits: Int
    var venue: String
    var faculty: String
    var slots: [Slot]

    init(id: Int, code: String, title: String, type: CourseType, credits: Int, venue: String, faculty: String, slots: [Slot] = []) {
        self.id = id
        self.code = code
        self.title = title
        self.type = type
        self.credits = credits
        self.venue = venue
        self.faculty = faculty
        self.slots = slots
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id
    }
}
