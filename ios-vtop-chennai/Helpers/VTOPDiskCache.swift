import Foundation

/// File-based JSON cache under Application Support (keeps `UserDefaults` small for startup).
enum VTOPDiskCache {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static var storageRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("VTOP", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var cacheDirectory: URL { storageRoot }

    private static let metaFilename = "cache_meta.json"

    struct Meta: Codable {
        var schemaVersion: Int
        var lastPersistedAt: Date?
    }

    static func readMeta() -> Meta {
        let url = cacheDirectory.appendingPathComponent(metaFilename)
        guard let data = try? Data(contentsOf: url),
              let m = try? decoder.decode(Meta.self, from: data) else {
            return Meta(schemaVersion: 2, lastPersistedAt: nil)
        }
        return m
    }

    static func writeMeta(lastPersistedAt: Date) {
        let m = Meta(schemaVersion: 2, lastPersistedAt: lastPersistedAt)
        let url = cacheDirectory.appendingPathComponent(metaFilename)
        guard let data = try? encoder.encode(m) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func save<T: Encodable>(_ value: T, fileName: String) {
        let url = cacheDirectory.appendingPathComponent(fileName)
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load<T: Decodable>(_ type: T.Type, fileName: String) -> T? {
        let url = cacheDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    static func saveData(_ data: Data?, fileName: String) {
        let url = cacheDirectory.appendingPathComponent(fileName)
        if let data {
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func loadData(fileName: String) -> Data? {
        let url = cacheDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    static func clearAllFiles() {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: cacheDirectory.path) else { return }
        for n in names {
            try? fm.removeItem(at: cacheDirectory.appendingPathComponent(n))
        }
    }
}
