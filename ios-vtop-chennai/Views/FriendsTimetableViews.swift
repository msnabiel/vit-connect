import SwiftUI
import UniformTypeIdentifiers

struct ImportFriendsTimetableView: View {
    @EnvironmentObject var friendsStore: FriendsTimetableStore
    @State private var isImporterPresented = false
    @State private var importMessage: String?
    @State private var pendingImportURL: URL?
    @State private var importDisplayName = ""
    @State private var showNamePrompt = false

    var body: some View {
        List {
            Section {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Choose timetable JSON", systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("Import a `.json` timetable shared by your friend.")
            }
        }
        .navigationTitle("Import timetable")
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                pendingImportURL = url
                importDisplayName = suggestedName(from: url)
                showNamePrompt = true
            case .failure:
                importMessage = "Import cancelled or failed."
            }
        }
        .alert("Name this timetable", isPresented: $showNamePrompt) {
            TextField("Friend name or label", text: $importDisplayName)
            Button("Cancel", role: .cancel) {
                pendingImportURL = nil
            }
            Button("Import") {
                guard let url = pendingImportURL else { return }
                let success = friendsStore.importFromJSONFile(at: url, displayName: importDisplayName)
                importMessage = success ? "Timetable imported to Friends list." : "Invalid timetable JSON."
                pendingImportURL = nil
            }
        } message: {
            Text("You can edit this name later.")
        }
        .alert("Import", isPresented: Binding(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button("OK", role: .cancel) { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
    }

    private func suggestedName(from url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        return base.replacingOccurrences(of: "-timetable", with: "", options: .caseInsensitive)
    }
}

struct FriendsTimetableListView: View {
    @EnvironmentObject var friendsStore: FriendsTimetableStore
    @State private var renameEntryId: UUID?
    @State private var renameText = ""

    var body: some View {
        List {
            if friendsStore.entries.isEmpty {
                Section {
                    Text("No imported timetables yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(friendsStore.entries) { entry in
                    NavigationLink(destination: FriendTimetableDetailView(entry: entry)) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.name)
                                    .font(.headline)
                                Text(entry.importedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Menu {
                                Button("Rename", systemImage: "pencil") {
                                    renameEntryId = entry.id
                                    renameText = entry.name
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    if let idx = friendsStore.entries.firstIndex(where: { $0.id == entry.id }) {
                                        friendsStore.delete(at: IndexSet(integer: idx))
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Rename") {
                            renameEntryId = entry.id
                            renameText = entry.name
                        }
                        .tint(.blue)
                    }
                }
                .onDelete(perform: friendsStore.delete)
            }
        }
        .navigationTitle("Friends timetable")
        .alert("Rename timetable", isPresented: Binding(
            get: { renameEntryId != nil },
            set: { if !$0 { renameEntryId = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameEntryId = nil
            }
            Button("Save") {
                guard let id = renameEntryId else { return }
                friendsStore.rename(entryId: id, to: renameText)
                renameEntryId = nil
            }
        }
    }
}

struct CompareTimetablesView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var friendsStore: FriendsTimetableStore
    @State private var selectedFriendIds: Set<UUID> = []

    private var myCourses: [Course] { dataManager.courses }
    private var selectedEntries: [FriendTimetableEntry] {
        friendsStore.entries.filter { selectedFriendIds.contains($0.id) }
    }

    private var friendCourseKeysById: [UUID: Set<String>] {
        Dictionary(uniqueKeysWithValues: selectedEntries.map { entry in
            (entry.id, Set(entry.payload.courses.map(courseKey)))
        })
    }

    private var myCourseMap: [String: Course] {
        Dictionary(uniqueKeysWithValues: myCourses.map { (courseKey($0), $0) })
    }

    private var allCourseDetails: [CourseDetail] {
        let myKeys = Set(myCourseMap.keys)
        let friendKeys = Set(friendCourseKeysById.values.flatMap { $0 })
        let universe = myKeys.union(friendKeys)

        return universe.compactMap { key in
            let template = myCourseMap[key]
                ?? selectedEntries.first(where: { entry in
                    entry.payload.courses.contains(where: { courseKey($0) == key })
                })?.payload.courses.first(where: { courseKey($0) == key })
            guard let course = template else { return nil }

            var ownerNames: [String] = []
            if myKeys.contains(key) { ownerNames.append("You") }
            for entry in selectedEntries where friendCourseKeysById[entry.id]?.contains(key) == true {
                ownerNames.append(entry.name)
            }
            return CourseDetail(course: course, owners: ownerNames, key: key)
        }
        .sorted {
            let l = $0.course.code.isEmpty ? $0.course.title : $0.course.code
            let r = $1.course.code.isEmpty ? $1.course.title : $1.course.code
            return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
        }
    }

    private var commonAllDetails: [CourseDetail] {
        let requiredOwners = selectedEntries.count + 1
        return allCourseDetails.filter { $0.owners.count == requiredOwners }
    }

    private var commonAnyDetails: [CourseDetail] {
        allCourseDetails.filter { detail in
            detail.owners.contains("You") && detail.owners.count >= 2
        }
    }

    private var onlyMyDetails: [CourseDetail] {
        allCourseDetails.filter { $0.owners == ["You"] }
    }

    private var onlyFriendDetails: [CourseDetail] {
        allCourseDetails.filter { !$0.owners.contains("You") }
    }

    private var freeOverlapSlotCount: Int {
        let allParticipants = [Participant(name: "You", timetable: dataManager.timetable, courses: dataManager.courses)]
        + selectedEntries.map { Participant(name: $0.name, timetable: $0.payload.timetable, courses: $0.payload.courses) }

        let allTimeDayKeys = Set(allParticipants.flatMap { participant in
            participant.timetable.flatMap { slot in
                (0...6).map { day in "\(day)|\(slot.startTime)-\(slot.endTime)" }
            }
        })

        let occupiedByParticipant: [Set<String>] = allParticipants.map { participant in
            Set(participant.timetable.flatMap { slot in
                (0...6).compactMap { day -> String? in
                    guard slot.matchingCourse(on: day, courses: participant.courses) != nil else { return nil }
                    return "\(day)|\(slot.startTime)-\(slot.endTime)"
                }
            })
        }

        return allTimeDayKeys.reduce(into: 0) { count, key in
            if occupiedByParticipant.allSatisfy({ !$0.contains(key) }) {
                count += 1
            }
        }
    }

    var body: some View {
        List {
            if friendsStore.entries.isEmpty {
                Section {
                    Text("Import a friend's timetable first.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Select friends") {
                    ForEach(friendsStore.entries) { entry in
                        Button {
                            toggleSelection(for: entry.id)
                        } label: {
                            HStack {
                                Text(entry.name)
                                Spacer()
                                if selectedFriendIds.contains(entry.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CompareChip(title: "All common", value: commonAllDetails.count)
                            CompareChip(title: "Any common", value: commonAnyDetails.count)
                            CompareChip(title: "Free overlap slots", value: freeOverlapSlotCount)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Common with all selected (\(commonAllDetails.count))") {
                    if commonAllDetails.isEmpty {
                        Text("No common classes.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(commonAllDetails, id: \.key) { detail in
                            CourseCompareRow(detail: detail)
                        }
                    }
                }

                Section("Common with at least one (\(commonAnyDetails.count))") {
                    if commonAnyDetails.isEmpty {
                        Text("No overlap with selected friends.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(commonAnyDetails, id: \.key) { detail in
                            CourseCompareRow(detail: detail)
                        }
                    }
                }

                Section("Only you (\(onlyMyDetails.count))") {
                    if onlyMyDetails.isEmpty {
                        Text("No exclusive classes.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(onlyMyDetails, id: \.key) { detail in
                            CourseCompareRow(detail: detail)
                        }
                    }
                }

                Section("Only selected friends (\(onlyFriendDetails.count))") {
                    if onlyFriendDetails.isEmpty {
                        Text("No exclusive classes.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(onlyFriendDetails, id: \.key) { detail in
                            CourseCompareRow(detail: detail)
                        }
                    }
                }
            }
        }
        .navigationTitle("Compare timetables")
        .onAppear {
            if selectedFriendIds.isEmpty, let first = friendsStore.entries.first?.id {
                selectedFriendIds.insert(first)
            }
        }
    }

    private func courseKey(_ course: Course) -> String {
        let code = course.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !code.isEmpty { return code }
        return course.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func toggleSelection(for id: UUID) {
        if selectedFriendIds.contains(id) {
            selectedFriendIds.remove(id)
        } else {
            selectedFriendIds.insert(id)
        }
        if selectedFriendIds.isEmpty {
            selectedFriendIds.insert(id)
        }
    }
}

private struct CourseCompareRow: View {
    let detail: CourseDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detail.course.code.isEmpty ? detail.course.title : "\(detail.course.code) • \(detail.course.title)")
                .font(.subheadline.weight(.semibold))
            Text(detail.course.type.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(detail.owners.joined(separator: " • "))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CompareChip: View {
    let title: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
            Text("\(value)")
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

private struct CourseDetail {
    let course: Course
    let owners: [String]
    let key: String
}

private struct Participant {
    let name: String
    let timetable: [TimetableSlot]
    let courses: [Course]
}

struct FriendTimetableDetailView: View {
    let entry: FriendTimetableEntry

    var body: some View {
        TimetableBrowserView(timetable: entry.payload.timetable, courses: entry.payload.courses)
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct TimetableBrowserView: View {
    let timetable: [TimetableSlot]
    let courses: [Course]

    @State private var selectedDay = Calendar.current.component(.weekday, from: Date()) - 1
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var orderedWeekdayIndices: [Int] {
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        return (0..<7).map { (today + $0) % 7 }
    }

    private var enrolledSlotsForSelectedDay: [TimetableSlot] {
        timetable
            .filter { $0.matchingCourse(on: selectedDay, courses: courses) != nil }
            .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(orderedWeekdayIndices, id: \.self) { dayIndex in
                        Button {
                            selectedDay = dayIndex
                        } label: {
                            VStack(spacing: 4) {
                                Text(weekdays[dayIndex])
                                    .font(.system(size: 14, weight: selectedDay == dayIndex ? .bold : .medium))
                                    .foregroundColor(selectedDay == dayIndex ? .white : .primary)
                                Circle()
                                    .fill(dayIndicatorFill(dayIndex: dayIndex))
                                    .frame(width: 6, height: 6)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedDay == dayIndex ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)

            if timetable.isEmpty {
                EmptyStateView(icon: "calendar", title: "No Timetable", message: "No data available")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if enrolledSlotsForSelectedDay.isEmpty {
                            Text("No class on this day")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(enrolledSlotsForSelectedDay) { slot in
                                TimetableSlotCard(slot: slot, dayIndex: selectedDay, courses: courses)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func dayIndicatorFill(dayIndex: Int) -> Color {
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        guard dayIndex == today else { return .clear }
        return selectedDay == dayIndex ? .white : .accentColor
    }
}
