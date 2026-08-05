import Foundation

/// Shared payload for widgets, Live Activities, and notification copy. Written on each successful persist.
struct VTOPGlanceSnapshot: Codable, Sendable {
    var updatedAt: Date
    var semesterName: String?
    var attendancePercent: Int?
    var nextClassTitle: String?
    var nextClassVenue: String?
    var nextClassStart: Date?
    var nextClassEnd: Date?
    var attendanceRiskLabel: String?
    var nextExamTitle: String?
    var nextExamDate: Date?
    var nextExamVenue: String?
    /// Short lines for “today” (e.g. "09:00 · Course · Venue")
    var todaySlotLines: [String]

    static let appGroupIdentifier = "group.com.msnabiel.vit-connect"
    static let snapshotFileName = "glance_snapshot.json"

    static func sharedSnapshotURL() -> URL? {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return group.appendingPathComponent(snapshotFileName)
        }
        return VTOPDiskCache.storageRoot.appendingPathComponent(snapshotFileName)
    }

    static func loadShared() -> Self? {
        guard let url = sharedSnapshotURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Self.self, from: data)
    }

    func writeToSharedContainer() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(self) else { return }
        if let url = Self.sharedSnapshotURL() {
            try? data.write(to: url, options: .atomic)
        }
    }
}
