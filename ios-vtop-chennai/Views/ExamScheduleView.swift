import SwiftUI

struct ExamScheduleView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var semesterId: String = ""
    @State private var didLoadPicklist = false
    @State private var pickerPrimed = false
    @State private var searchText: String = ""
    @State private var selectedCategoryTitle: String = ""
    @State private var calendarMessage: String?
    @State private var isExportingCalendar = false

    private var choices: [Semester] { dataManager.examScheduleSemesterOptions }

    private var semesterMenuTitle: String {
        choices.first(where: { $0.id == semesterId })?.name ?? "Choose semester"
    }

    private var searchFilteredExams: [Exam] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return dataManager.exams }
        return dataManager.exams.filter { Self.examMatchesSearch($0, query: q) }
    }

    /// Groups exams by category (FAT, CAT1, …) with a sensible header order.
    private var examSections: [(title: String, exams: [Exam])] {
        Self.groupExams(searchFilteredExams)
    }

    /// When several categories exist (e.g. CAT1 / CAT2 / FAT), show one at a time via segmented control.
    private var sectionsToDisplay: [(title: String, exams: [Exam])] {
        let s = examSections
        if s.isEmpty { return [] }
        if s.count == 1 { return s }
        if let picked = s.first(where: { $0.title == selectedCategoryTitle }) {
            return [picked]
        }
        return [s[0]]
    }

    private var examSectionSignature: String {
        examSections.map { "\($0.title):\($0.exams.count)" }.joined(separator: "|")
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            VStack(spacing: 0) {
            if !choices.isEmpty {
                SemesterMenuView(
                    choices: choices,
                    selectedName: semesterMenuTitle,
                    bottomPadding: 4,
                    onSelect: { semester in
                    semesterId = semester.id
                    if pickerPrimed {
                        dataManager.refreshExamSchedule(semesterSubId: semester.id, completion: nil)
                    }
                    }
                )
            }

            if !choices.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("Course, venue, slot…", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }

            if examSections.count > 1 {
                Picker("Exam category", selection: $selectedCategoryTitle) {
                    ForEach(examSections, id: \.title) { sec in
                        Text(sec.title).tag(sec.title)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            if dataManager.exams.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.exclamationmark",
                    message: choices.isEmpty
                        ? "Open this screen while signed in to load semester options, or run a full sync."
                        : "Choose a semester above to load your exam schedule."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if examSections.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    message: "No exams match your search."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sectionsToDisplay, id: \.title) { category in
                        Section {
                            ForEach(category.exams) { exam in
                                ExamScheduleNestedExamSection(exam: exam, courses: dataManager.courses)
                            }
                        } header: {
                            Text(category.title)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            }
        }
        .onChange(of: examSectionSignature) { _, _ in
            syncSelectedCategoryWithSections()
        }
        .onAppear {
            syncSelectedCategoryWithSections()
        }
        .navigationTitle("Exam Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isExportingCalendar = true
                    Task {
                        do {
                            let count = try await VTOPCalendarExportService.export(exams: dataManager.exams)
                            calendarMessage = "Added \(count) exam\(count == 1 ? "" : "s") to Calendar."
                        } catch {
                            calendarMessage = error.localizedDescription
                        }
                        isExportingCalendar = false
                    }
                } label: {
                    Label("Add exams to Calendar", systemImage: "calendar.badge.plus")
                }
                .disabled(dataManager.exams.isEmpty || isExportingCalendar)
            }
        }
        .alert("Calendar", isPresented: Binding(
            get: { calendarMessage != nil },
            set: { if !$0 { calendarMessage = nil } }
        )) {
            Button("OK", role: .cancel) { calendarMessage = nil }
        } message: {
            Text(calendarMessage ?? "")
        }
        .refreshable {
            if choices.isEmpty {
                await dataManager.loadExamScheduleSemesterPicklist()
            } else if !semesterId.isEmpty {
                await dataManager.refreshExamSchedule(for: semesterId)
                }
        }
        .onAppear {
            guard !didLoadPicklist else { return }
            didLoadPicklist = true
            dataManager.loadExamScheduleSemesterPicklist {
                let c = dataManager.examScheduleSemesterOptions
                if semesterId.isEmpty {
                    if let sid = dataManager.examScheduleSemesterId, c.contains(where: { $0.id == sid }) {
                        semesterId = sid
                    } else if let sid = dataManager.selectedSemester?.id, c.contains(where: { $0.id == sid }) {
                        semesterId = sid
                    } else if let first = c.first {
                        semesterId = first.id
                    }
                }
                pickerPrimed = true
                if !semesterId.isEmpty {
                    dataManager.refreshExamSchedule(semesterSubId: semesterId, completion: nil)
                }
            }
        }
    }

    private func syncSelectedCategoryWithSections() {
        let titles = examSections.map(\.title)
        guard !titles.isEmpty else {
            selectedCategoryTitle = ""
            return
        }
        if !titles.contains(selectedCategoryTitle) {
            selectedCategoryTitle = titles[0]
        }
    }

    private static func examMatchesSearch(_ exam: Exam, query: String) -> Bool {
        let parts: [String] = [
            exam.courseCode,
            exam.courseTitle,
            exam.title,
            exam.examCategory,
            exam.venue,
            exam.slotText,
            exam.examDateText,
            exam.sessionLabel,
            exam.reportingTimeText,
            exam.examTimeRangeText,
            exam.seatLocation,
            exam.classIdText,
            exam.courseTypeAbbrev
        ].compactMap { $0 }
        let joined = parts.joined(separator: " ").lowercased()
        if joined.contains(query) { return true }
        if let n = exam.seatNumber, String(n).lowercased().contains(query) { return true }
        return false
    }

    private static func groupExams(_ exams: [Exam]) -> [(title: String, exams: [Exam])] {
        let grouped = Dictionary(grouping: exams) { exam -> String in
            let c = (exam.examCategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !c.isEmpty { return c }
            let t = exam.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
            return "Other"
        }
        let keys = grouped.keys.sorted { a, b in
            let oa = categorySortOrder(a)
            let ob = categorySortOrder(b)
            if oa != ob { return oa < ob }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
        return keys.map { key in
            let rows = (grouped[key] ?? []).sorted {
                ($0.startTime ?? Int64.max) < ($1.startTime ?? Int64.max)
            }
            return (title: key, exams: rows)
        }
    }

    private static func categorySortOrder(_ name: String) -> Int {
        let u = name.uppercased()
        if u.contains("FAT") { return 0 }
        if u.contains("CAT") { return 1 }
        if u.contains("MODEL") || u.contains("MID") { return 2 }
        return 9
    }
}

// MARK: - List rows (system style)

private struct ExamScheduleNestedExamSection: View {
    let exam: Exam
    let courses: [Course]

    private var course: Course? {
        exam.matchingCatalogCourse(in: courses)
    }

    var body: some View {
        Section {
            ExamScheduleFieldRows(exam: exam, course: course)
        } header: {
            ExamScheduleExamHeader(exam: exam, course: course)
        } footer: {
            Text("Please verify exam details on VTOP before the exam.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ExamScheduleExamHeader: View {
    let exam: Exam
    let course: Course?

    private var titleText: String {
        let fromExam = (exam.courseTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromExam.isEmpty { return fromExam }
        if let c = course?.title, !c.isEmpty { return c }
        return exam.title
    }

    private var codeText: String {
        let fromExam = (exam.courseCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromExam.isEmpty { return fromExam }
        return course?.code ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleText)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Text(codeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textCase(nil)
        .padding(.vertical, 2)
    }
}

private struct ExamScheduleFieldRows: View {
    let exam: Exam
    let course: Course?

    var body: some View {
        if let date = exam.examDateText, !date.isEmpty {
            LabeledContent {
                Text(date)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
            } label: {
                Label("Exam date", systemImage: "calendar")
            }
        }
        if let slot = exam.slotText, !slot.isEmpty {
            LabeledContent {
                Text(slot)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Slot", systemImage: "clock.fill")
            }
        }
        if let session = exam.sessionLabel, !session.isEmpty {
            LabeledContent {
                Text(session)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Session", systemImage: "sun.horizon.fill")
            }
        }
        if let rep = exam.reportingTimeText, !rep.isEmpty {
            LabeledContent {
                Text(rep)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Reporting time", systemImage: "bell.fill")
            }
        }
        if let span = exam.examTimeRangeText, !span.isEmpty {
            LabeledContent {
                Text(span)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Exam time", systemImage: "timer")
            }
        }
        if let venue = exam.venue, !venue.isEmpty {
            LabeledContent {
                Text(venue)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Venue", systemImage: "mappin.circle.fill")
            }
        }
        if let seatLocation = exam.seatLocation, !seatLocation.isEmpty {
            LabeledContent {
                Text(seatLocation)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Seat location", systemImage: "person.crop.square.fill")
            }
        }
        if let seatNumber = exam.seatNumber {
            LabeledContent {
                Text("\(seatNumber)")
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Seat number", systemImage: "number.circle.fill")
            }
        }
        if let course = course {
            LabeledContent {
                Text(course.type.rawValue.capitalized)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Course type", systemImage: "book.fill")
            }
            LabeledContent {
                Text(course.faculty)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Faculty", systemImage: "person.fill")
            }
        } else if let abbr = exam.courseTypeAbbrev, !abbr.isEmpty {
            LabeledContent {
                Text(abbr)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Course type", systemImage: "book.fill")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExamScheduleView()
            .environmentObject(DataManager())
            .environmentObject(DataManagerSyncState())
    }
}
