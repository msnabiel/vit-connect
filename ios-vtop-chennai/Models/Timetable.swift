import Foundation

struct TimetableSlot: Codable, Identifiable, Hashable {
    let id: Int
    var startTime: String  // HH:mm format
    var endTime: String    // HH:mm format
    /// Slot token for that day (e.g. `G1`, `D1`) — matches `Course.slots[].slot` after stripping VTOP detail suffixes.
    var sunday: String?
    var monday: String?
    var tuesday: String?
    var wednesday: String?
    var thursday: String?
    var friday: String?
    var saturday: String?

    init(id: Int, startTime: String, endTime: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.sunday = nil
        self.monday = nil
        self.tuesday = nil
        self.wednesday = nil
        self.thursday = nil
        self.friday = nil
        self.saturday = nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TimetableSlot, rhs: TimetableSlot) -> Bool {
        lhs.id == rhs.id
    }
}

extension TimetableSlot {
    /// Slot label for this weekday (`dayIndex`: 0 = Sunday … 6 = Saturday).
    func slotCode(on dayIndex: Int) -> String? {
        let raw: String?
        switch dayIndex {
        case 0: raw = sunday
        case 1: raw = monday
        case 2: raw = tuesday
        case 3: raw = wednesday
        case 4: raw = thursday
        case 5: raw = friday
        case 6: raw = saturday
        default: raw = nil
        }
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        return r
    }

    /// Course registered for this period, if the grid cell matches one of your slot codes.
    func matchingCourse(on dayIndex: Int, courses: [Course]) -> Course? {
        guard let code = slotCode(on: dayIndex) else { return nil }
        return courses.first { course in
            course.slots.contains { $0.slot.caseInsensitiveCompare(code) == .orderedSame }
        }
    }
}
