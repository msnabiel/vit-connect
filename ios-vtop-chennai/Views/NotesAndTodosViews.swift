import SwiftUI

private enum NotesHubTab: Int, CaseIterable {
    case notes
    case todos
}

struct NotesAndTodosHubView: View {
    @EnvironmentObject var store: NotesAndTodosStore
    @EnvironmentObject var dataManager: DataManager
    @State private var tab: NotesHubTab = .notes

    var body: some View {
        // No nested NavigationStack — Profile already uses NavigationStack; nesting caused extra
        // safe-area inset and made the page look shifted down vs. Courses and other pushes.
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                Text("Notes")
                    .tag(NotesHubTab.notes)
                Text("To-Do")
                    .tag(NotesHubTab.todos)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            Group {
                switch tab {
                case .notes:
                    NotesListView()
                case .todos:
                    TodosListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle("Notes & To-Do")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                switch tab {
                case .notes:
                    NavigationLink {
                        NoteEditorView(note: nil)
                    } label: {
                        Label("New note", systemImage: "square.and.pencil")
                            .labelStyle(.iconOnly)
                    }
                case .todos:
                    NavigationLink {
                        TodoEditorView(todo: nil)
                    } label: {
                        Label("New task", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }
}

// MARK: - Course link

private struct CourseLinkPicker: View {
    let courses: [Course]
    @Binding var linkedCourseId: Int?

    private var label: String {
        guard let id = linkedCourseId,
              let c = courses.first(where: { $0.id == id }) else {
            return "Link course (optional)"
        }
        return c.code.isEmpty ? c.title : "\(c.code) · \(c.title)"
    }

    var body: some View {
        Menu {
            Button("No course") { linkedCourseId = nil }
            if !courses.isEmpty {
                Divider()
                ForEach(courses) { c in
                    Button {
                        linkedCourseId = c.id
                    } label: {
                        Text(c.code.isEmpty ? c.title : "\(c.code) · \(c.title)")
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func courseLabel(id: Int?, courses: [Course]) -> String? {
    guard let id, let c = courses.first(where: { $0.id == id }) else { return nil }
    return c.code.isEmpty ? c.title : "\(c.code)"
}

// MARK: - Notes

struct NotesListView: View {
    @EnvironmentObject var store: NotesAndTodosStore
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        Group {
            if store.notes.isEmpty {
                ContentUnavailableView(
                    "No notes yet",
                    systemImage: "note.text",
                    description: Text("Use the button above to add a note. You can link a course.")
                )
            } else {
                List {
                    ForEach(store.notes) { note in
                        NavigationLink(destination: NoteEditorView(note: note)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title.isEmpty ? "Untitled" : note.title)
                                    .font(.headline)
                                if let link = courseLabel(id: note.linkedCourseId, courses: dataManager.courses) {
                                    Text(link)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { store.deleteNotes(at: $0) }
                }
                .listStyle(.plain)
                .contentMargins(.top, 0, for: .scrollContent)
            }
        }
    }
}

struct NoteEditorView: View {
    @EnvironmentObject var store: NotesAndTodosStore
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    let note: StudentNote?

    @State private var titleText = ""
    @State private var bodyText = ""
    @State private var linkedCourseId: Int?

    private enum FocusField: Hashable {
        case title, body
    }

    @FocusState private var focused: FocusField?

    init(note: StudentNote?) {
        self.note = note
    }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $titleText)
                    .focused($focused, equals: .title)
                CourseLinkPicker(courses: dataManager.courses, linkedCourseId: $linkedCourseId)
            }
            Section {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 180)
                    .focused($focused, equals: .body)
            } header: {
                Text("Note")
            }
        }
        .navigationTitle(note == nil ? "New note" : "Edit note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focused = nil
                }
            }
        }
        .onAppear {
            if let n = note {
                titleText = n.title
                bodyText = n.body
                linkedCourseId = n.linkedCourseId
            }
        }
    }

    private func save() {
        let t = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if var existing = note {
            existing.title = t.isEmpty ? "Untitled" : t
            existing.body = b
            existing.linkedCourseId = linkedCourseId
            store.updateNote(existing)
        } else {
            store.addNote(title: t.isEmpty ? "Untitled" : t, body: b, linkedCourseId: linkedCourseId)
        }
        dismiss()
    }
}

// MARK: - To-Dos

struct TodosListView: View {
    @EnvironmentObject var store: NotesAndTodosStore
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        Group {
            if store.todos.isEmpty {
                ContentUnavailableView(
                    "No tasks yet",
                    systemImage: "checklist",
                    description: Text("Use the button above to add a to-do. Link a course if you want.")
                )
            } else {
                List {
                    ForEach(store.todos) { todo in
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                store.toggleTodo(todo.id)
                            } label: {
                                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(todo.title)
                                    .font(.body)
                                    .strikethrough(todo.isCompleted)
                                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                                if let link = courseLabel(id: todo.linkedCourseId, courses: dataManager.courses) {
                                    Text(link)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let due = todo.dueDate {
                                    Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            NavigationLink(destination: TodoEditorView(todo: todo)) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { store.deleteTodos(at: $0) }
                }
                .listStyle(.plain)
                .contentMargins(.top, 0, for: .scrollContent)
            }
        }
    }
}

struct TodoEditorView: View {
    @EnvironmentObject var store: NotesAndTodosStore
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    let todo: StudentTodo?

    @State private var titleText = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var linkedCourseId: Int?

    @FocusState private var titleFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("Task", text: $titleText)
                    .focused($titleFocused)
                CourseLinkPicker(courses: dataManager.courses, linkedCourseId: $linkedCourseId)
                Toggle("Due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }
            }
        }
        .navigationTitle(todo == nil ? "New task" : "Edit task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    titleFocused = false
                }
            }
        }
        .onAppear {
            if let t = todo {
                titleText = t.title
                linkedCourseId = t.linkedCourseId
                if let d = t.dueDate {
                    hasDueDate = true
                    dueDate = d
                }
            }
        }
    }

    private func save() {
        let t = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let due = hasDueDate ? dueDate : nil
        if var existing = todo {
            existing.title = t
            existing.dueDate = due
            existing.linkedCourseId = linkedCourseId
            store.updateTodo(existing)
        } else {
            store.addTodo(title: t, dueDate: due, linkedCourseId: linkedCourseId)
        }
        dismiss()
    }
}
