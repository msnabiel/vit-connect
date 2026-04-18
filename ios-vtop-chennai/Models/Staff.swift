import Foundation

enum StaffType: String, Codable {
    case proctor = "PROCTOR"
    case dean = "DEAN"
    case hod = "HOD"
}

struct Staff: Codable, Identifiable, Hashable {
    let id: Int
    var type: StaffType
    var key: String
    var value: String

    init(id: Int, type: StaffType, key: String, value: String) {
        self.id = id
        self.type = type
        self.key = key
        self.value = value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Staff, rhs: Staff) -> Bool {
        lhs.id == rhs.id
    }
}
