import Foundation

struct FriendTimetableEntry: Codable, Identifiable {
    let id: UUID
    var name: String
    let importedAt: Date
    let payload: TimetableSharePayload
}

final class FriendsTimetableStore: ObservableObject {
    @Published private(set) var entries: [FriendTimetableEntry] = []

    private let storageKey = "friends_timetables_v1"

    private var persistenceAllowed: Bool {
        AppCacheSettings.UserStore.isEnabled(.friendsImports)
    }
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        if persistenceAllowed {
            load()
        } else {
            entries = []
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    func importFromJSONFile(at url: URL, displayName: String?) -> Bool {
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url),
              let payload = TimetableShareCodec.decodePayload(from: data) else {
            return false
        }

        let trimmed = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = payload.semesterName?.isEmpty == false ? payload.semesterName! : "Friend timetable"
        let entry = FriendTimetableEntry(
            id: UUID(),
            name: trimmed.isEmpty ? fallback : trimmed,
            importedAt: Date(),
            payload: payload
        )
        entries.insert(entry, at: 0)
        persist()
        return true
    }

    /// Call after the user changes the “save friends imports” toggle in Cache management.
    func applyCacheSettingsPreference() {
        if persistenceAllowed {
            load()
        } else {
            clearAll()
        }
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        persist()
    }

    func rename(entryId: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[idx].name = trimmed
        persist()
    }

    func clearAll() {
        entries = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func load() {
        guard persistenceAllowed else { return }
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? decoder.decode([FriendTimetableEntry].self, from: data) else { return }
        entries = decoded
    }

    private func persist() {
        guard persistenceAllowed else { return }
        guard let data = try? encoder.encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
