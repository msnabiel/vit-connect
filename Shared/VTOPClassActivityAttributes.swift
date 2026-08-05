import ActivityKit
import Foundation

struct VTOPClassActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startsInMinutes: Int
        var venue: String
        var courseTitle: String
    }

    var slotStart: Date
}
