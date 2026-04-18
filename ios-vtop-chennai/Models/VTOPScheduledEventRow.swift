import Foundation

/// One row from `/vtop/get/scheduled/events` (campus calendar cards).
struct VTOPScheduledEventRow: Codable, Identifiable, Hashable {
    let id: String
    /// Stable key for one date column + banner within the HTML card.
    let groupKey: String
    let sectionBanner: String
    let day: String
    let monthYear: String
    let title: String?
    let detailLine: String
    let venue: String
    let isPlaceholder: Bool
}
