import SwiftUI

struct CacheManagementView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var friendsStore: FriendsTimetableStore
    @EnvironmentObject var notesStore: NotesAndTodosStore

    @State private var confirmClearVtopCache = false
    @State private var confirmClearFriends = false
    @State private var confirmClearNotesTodos = false

    var body: some View {
        Form {
            Section {
                Text("Turn categories off to stop saving them on this device and remove what was stored. Turn them back on to load saved data again after a sync.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Sign out behavior")) {
                Toggle(isOn: clearOnSignOutBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear VTOP cache on sign out")
                        Text("Default is Off. When enabled, signing out also deletes saved VTOP data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(header: Text("VTOP — save on device")) {
                LabeledContent("Cache linked to register no.") {
                    Text(AppCacheSettings.activeRegisterNumber() ?? "Not linked yet")
                        .foregroundStyle(.secondary)
                }
                if let cached = dataManager.cachePersistedAt {
                    LabeledContent("Last saved") {
                        Text(cached.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
                if let last = dataManager.lastSuccessfulSyncAt {
                    LabeledContent("Last sync") {
                        Text(last.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(AppCacheSettings.VTOPBucket.allCases) { bucket in
                    Toggle(isOn: vtopBinding(for: bucket)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bucket.title)
                                .font(.body)
                            Text(vtopFootnote(for: bucket))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button(role: .destructive) {
                    confirmClearVtopCache = true
                } label: {
                    Label("Clear all VTOP cache", systemImage: "trash")
                }
            }

            Section(header: Text("Friends")) {
                Toggle(isOn: friendsBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppCacheSettings.UserStore.friendsImports.title)
                        Text("Imported friend timetables only.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Imports on device") {
                    Text("\(friendsStore.entries.count)")
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    confirmClearFriends = true
                } label: {
                    Label("Clear friends imports now", systemImage: "trash")
                }
            }

            Section(header: Text("Notes & To‑Do")) {
                Toggle(isOn: notesBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppCacheSettings.UserStore.notesAndTodos.title)
                        Text("Your notes and tasks created in the app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Notes / tasks") {
                    Text("\(notesStore.notes.count) / \(notesStore.todos.count)")
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    confirmClearNotesTodos = true
                } label: {
                    Label("Clear notes & to‑dos now", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Cache management")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear all VTOP cache?", isPresented: $confirmClearVtopCache) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                dataManager.clearCachedVTOPData()
            }
        } message: {
            Text("Removes every saved VTOP category from this device. You stay signed in; use Full Sync Data to download again.")
        }
        .alert("Clear imported friends timetables?", isPresented: $confirmClearFriends) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                friendsStore.clearAll()
            }
        } message: {
            Text("Removes friend timetable imports stored on this device.")
        }
        .alert("Clear notes & to-dos?", isPresented: $confirmClearNotesTodos) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                notesStore.clearAll()
            }
        } message: {
            Text("Removes notes and to-dos stored on this device.")
        }
    }

    private func vtopBinding(for bucket: AppCacheSettings.VTOPBucket) -> Binding<Bool> {
        Binding(
            get: { AppCacheSettings.VTOPBucket.isEnabled(bucket) },
            set: { newValue in
                AppCacheSettings.VTOPBucket.setEnabled(bucket, newValue)
                dataManager.applyVTOPCacheBucket(enabled: newValue, bucket: bucket)
            }
        )
    }

    private func vtopFootnote(for bucket: AppCacheSettings.VTOPBucket) -> String {
        switch bucket {
        case .profileSummary:
            return "Name, CGPA, credits snapshot."
        case .academic:
            return "Courses, timetable, attendance, semesters."
        case .marksAndGrades:
            return "Marks, grade history, marks report."
        case .exams:
            return "Exams and exam schedule picks."
        case .receipts:
            return "Payment receipt list."
        case .campusExtras:
            return "Staff, calendar events, portal credentials, rank, portraits."
        }
    }

    private var friendsBinding: Binding<Bool> {
        Binding(
            get: { AppCacheSettings.UserStore.isEnabled(.friendsImports) },
            set: { newValue in
                AppCacheSettings.UserStore.setEnabled(.friendsImports, newValue)
                friendsStore.applyCacheSettingsPreference()
            }
        )
    }

    private var notesBinding: Binding<Bool> {
        Binding(
            get: { AppCacheSettings.UserStore.isEnabled(.notesAndTodos) },
            set: { newValue in
                AppCacheSettings.UserStore.setEnabled(.notesAndTodos, newValue)
                notesStore.applyCacheSettingsPreference()
            }
        )
    }

    private var clearOnSignOutBinding: Binding<Bool> {
        Binding(
            get: { AppCacheSettings.clearCacheOnSignOutEnabled() },
            set: { AppCacheSettings.setClearCacheOnSignOutEnabled($0) }
        )
    }
}

#Preview {
    NavigationStack {
        CacheManagementView()
            .environmentObject(DataManager())
            .environmentObject(FriendsTimetableStore())
            .environmentObject(NotesAndTodosStore())
    }
}
