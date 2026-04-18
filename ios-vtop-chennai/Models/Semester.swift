import Foundation

struct Semester: Codable, Identifiable, Hashable {
    let id: String
    var name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Semester, rhs: Semester) -> Bool {
        lhs.id == rhs.id
    }
}
