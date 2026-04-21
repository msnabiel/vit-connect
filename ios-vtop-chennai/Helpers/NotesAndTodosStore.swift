import Foundation

struct StudentNote: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var body: String
    var linkedCourseId: Int?
    var createdAt: Date
    var updatedAt: Date
}

struct StudentTodo: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
    var linkedCourseId: Int?
    var createdAt: Date
}

final class NotesAndTodosStore: ObservableObject {
    @Published private(set) var notes: [StudentNote] = []
    @Published private(set) var todos: [StudentTodo] = []

    private let notesKey = "vtop_student_notes_v1"
    private let todosKey = "vtop_student_todos_v1"

    private var persistenceAllowed: Bool {
        AppCacheSettings.UserStore.isEnabled(.notesAndTodos)
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
            notes = []
            todos = []
            UserDefaults.standard.removeObject(forKey: notesKey)
            UserDefaults.standard.removeObject(forKey: todosKey)
        }
    }

    func addNote(title: String, body: String, linkedCourseId: Int?) {
        let now = Date()
        let note = StudentNote(
            id: UUID(),
            title: title,
            body: body,
            linkedCourseId: linkedCourseId,
            createdAt: now,
            updatedAt: now
        )
        notes.insert(note, at: 0)
        persistNotes()
    }

    func updateNote(_ note: StudentNote) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var n = note
        n.updatedAt = Date()
        notes[i] = n
        persistNotes()
    }

    func deleteNotes(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        persistNotes()
    }

    func addTodo(title: String, dueDate: Date?, linkedCourseId: Int?) {
        let item = StudentTodo(
            id: UUID(),
            title: title,
            isCompleted: false,
            dueDate: dueDate,
            linkedCourseId: linkedCourseId,
            createdAt: Date()
        )
        todos.insert(item, at: 0)
        persistTodos()
    }

    func toggleTodo(_ id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].isCompleted.toggle()
        persistTodos()
    }

    func updateTodo(_ todo: StudentTodo) {
        guard let i = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[i] = todo
        persistTodos()
    }

    func deleteTodos(at offsets: IndexSet) {
        todos.remove(atOffsets: offsets)
        persistTodos()
    }

    /// Call after the user changes the “save notes & to-dos” toggle in Cache management.
    func applyCacheSettingsPreference() {
        if persistenceAllowed {
            load()
        } else {
            clearAll()
        }
    }

    func clearAll() {
        notes = []
        todos = []
        UserDefaults.standard.removeObject(forKey: notesKey)
        UserDefaults.standard.removeObject(forKey: todosKey)
    }

    private func load() {
        guard persistenceAllowed else { return }
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let decoded = try? decoder.decode([StudentNote].self, from: data) {
            notes = decoded
        }
        if let data = UserDefaults.standard.data(forKey: todosKey),
           let decoded = try? decoder.decode([StudentTodo].self, from: data) {
            todos = decoded
        }
    }

    private func persistNotes() {
        guard persistenceAllowed else { return }
        guard let data = try? encoder.encode(notes) else { return }
        UserDefaults.standard.set(data, forKey: notesKey)
    }

    private func persistTodos() {
        guard persistenceAllowed else { return }
        guard let data = try? encoder.encode(todos) else { return }
        UserDefaults.standard.set(data, forKey: todosKey)
    }
}
