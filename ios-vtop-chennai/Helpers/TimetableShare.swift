import Foundation

struct TimetableSharePayload: Codable {
    let version: Int
    let semesterName: String?
    let exportedAt: Date
    let timetable: [TimetableSlot]
    let courses: [Course]

    init(semesterName: String?, timetable: [TimetableSlot], courses: [Course]) {
        self.version = 1
        self.semesterName = semesterName
        self.exportedAt = Date()
        self.timetable = timetable
        self.courses = courses
    }
}

enum TimetableShareCodec {
    static func encodePayload(_ payload: TimetableSharePayload) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    static func decodePayload(from data: Data) -> TimetableSharePayload? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TimetableSharePayload.self, from: data)
    }

    static func writePayloadFile(_ payload: TimetableSharePayload, filePrefix: String? = nil) -> URL? {
        guard let data = encodePayload(payload) else { return nil }

        let rawPrefix = (filePrefix ?? "timetable-share").trimmingCharacters(in: .whitespacesAndNewlines)
        let safePrefix = sanitizeFilenameComponent(rawPrefix.isEmpty ? "timetable-share" : rawPrefix)
        let filename = "\(safePrefix)-timetable.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func sanitizeFilenameComponent(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = text.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let collapsed = String(mapped).replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return trimmed.isEmpty ? "TIMETABLE-SHARE" : trimmed.uppercased()
    }

}
