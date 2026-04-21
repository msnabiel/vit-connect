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
    static let scheme = "vitstudent"
    static let host = "timetable"
    static let queryKey = "data"

    static func makeDeepLink(for payload: TimetableSharePayload) -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let jsonData = try? encoder.encode(payload) else { return nil }
        let encoded = base64URLEncode(jsonData)

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: queryKey, value: encoded)
        ]
        return components.url
    }

    static func decodeDeepLink(_ url: URL) -> TimetableSharePayload? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = components.queryItems?.first(where: { $0.name == queryKey })?.value,
              let data = base64URLDecode(encoded) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TimetableSharePayload.self, from: data)
    }

    static func writePayloadFile(_ payload: TimetableSharePayload) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return nil }

        let filename = "timetable-share-\(Int(Date().timeIntervalSince1970)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ text: String) -> Data? {
        var base64 = text
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
