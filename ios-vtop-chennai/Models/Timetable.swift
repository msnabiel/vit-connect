import Foundation

struct TimetableSlot: Codable, Identifiable, Hashable {
    let id: Int
    var startTime: String  // HH:mm format
    var endTime: String    // HH:mm format
    var sunday: Int?       // SlotId reference
    var monday: Int?
    var tuesday: Int?
    var wednesday: Int?
    var thursday: Int?
    var friday: Int?
    var saturday: Int?

    init(id: Int, startTime: String, endTime: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TimetableSlot, rhs: TimetableSlot) -> Bool {
        lhs.id == rhs.id
    }
}
