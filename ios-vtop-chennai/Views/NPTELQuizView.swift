import SwiftUI

// MARK: - Persistence

private struct QuizRecord: Codable {
    var bestScore: Int
    var totalQuestions: Int
    var bestTimeSeconds: Double
    var attempts: Int
}

fileprivate class NPTELQuizStore: ObservableObject {
    @Published var records: [String: QuizRecord] = [:]

    private let key = "nptel_quiz_records"

    init() { load() }

    private func recordKey(_ courseId: String, week: Int) -> String { "\(courseId)_week\(week)" }

    func record(courseId: String, week: Int) -> QuizRecord? {
        records[recordKey(courseId, week: week)]
    }

    func save(courseId: String, week: Int, score: Int, total: Int, timeSeconds: Double) {
        let k = recordKey(courseId, week: week)
        let existing = records[k]
        let bestScore = max(score, existing?.bestScore ?? 0)
        let bestTime: Double
        if let prev = existing, score >= bestScore, prev.bestScore == bestScore {
            bestTime = min(timeSeconds, prev.bestTimeSeconds)
        } else if score > (existing?.bestScore ?? -1) {
            bestTime = timeSeconds
        } else {
            bestTime = existing?.bestTimeSeconds ?? timeSeconds
        }
        records[k] = QuizRecord(
            bestScore: bestScore,
            totalQuestions: total,
            bestTimeSeconds: bestTime,
            attempts: (existing?.attempts ?? 0) + 1
        )
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: QuizRecord].self, from: data)
        else { return }
        records = decoded
    }
}

// MARK: - Course accent colors

private let courseAccents: [String: Color] = [
    "conservation": .green,
    "forests": Color(red: 0.3, green: 0.65, blue: 0.3),
    "scienceofhappiness": .orange,
    "wildlife": .brown
]

private let courseIcons: [String: String] = [
    "conservation": "leaf.fill",
    "forests": "tree.fill",
    "scienceofhappiness": "face.smiling.fill",
    "wildlife": "pawprint.fill"
]

// MARK: - Course List

struct NPTELQuizView: View {
    @StateObject private var store = NPTELQuizStore()

    private var totalAttempted: Int {
        nptelCourses.flatMap { course in
            course.questionsByWeek.keys.compactMap { store.record(courseId: course.id, week: $0) }
        }.count
    }
    private var totalCorrect: Int {
        nptelCourses.flatMap { course in
            course.questionsByWeek.keys.compactMap { store.record(courseId: course.id, week: $0) }
        }.reduce(0) { $0 + $1.bestScore }
    }
    private var totalQuestions: Int {
        nptelCourses.flatMap { course in
            course.questionsByWeek.keys.compactMap { store.record(courseId: course.id, week: $0) }
        }.reduce(0) { $0 + $1.totalQuestions }
    }
    private var totalAttempts: Int {
        nptelCourses.flatMap { course in
            course.questionsByWeek.keys.compactMap { store.record(courseId: course.id, week: $0) }
        }.reduce(0) { $0 + $1.attempts }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Your Statistics
                if totalAttempted > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Statistics")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        HStack(spacing: 0) {
                            statPill(icon: "book.closed.fill", color: .blue, title: "Weeks Done", value: "\(totalAttempted)")
                            Divider().frame(height: 36)
                            statPill(icon: "checkmark.circle.fill", color: .green, title: "Best Correct", value: "\(totalCorrect)/\(totalQuestions)")
                            Divider().frame(height: 36)
                            statPill(icon: "arrow.clockwise", color: .teal, title: "Total Tries", value: "\(totalAttempts)")
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                // Course cards
                ForEach(nptelCourses, id: \.id) { course in
                    let accent = courseAccents[course.id] ?? .blue
                    let icon = courseIcons[course.id] ?? "books.vertical.fill"
                    let totalWeeks = course.questionsByWeek.keys.count
                    let completed = course.questionsByWeek.keys.filter {
                        store.record(courseId: course.id, week: $0) != nil
                    }.count

                    NavigationLink(destination: NPTELWeekListView(course: course, store: store)) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(accent.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Image(systemName: icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(accent)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                HStack(spacing: 8) {
                                    Text("\(totalWeeks) weeks")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if completed > 0 {
                                        Text("·")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                        Text("\(completed)/\(totalWeeks) done")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(accent)
                                    }
                                }
                                if completed > 0 {
                                    ProgressView(value: Double(completed), total: Double(totalWeeks))
                                        .tint(accent)
                                        .frame(height: 4)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("NPTEL Quiz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statPill(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundColor(color)
                Text(value).font(.caption.weight(.bold))
            }
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Week List

private struct NPTELWeekListView: View {
    let course: NPTELCourse
    @ObservedObject var store: NPTELQuizStore
    @AppStorage("nptel_immediate_feedback") private var immediateFeedback = true
    @AppStorage("nptel_jumble_options") private var jumbleOptions = true

    private var accent: Color { courseAccents[course.id] ?? .blue }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $immediateFeedback) {
                    Label("Show answer immediately", systemImage: "eye.fill")
                }
                .tint(accent)
                Toggle(isOn: $jumbleOptions) {
                    Label("Jumble questions & answers", systemImage: "shuffle")
                }
                .tint(accent)
            } footer: {
                Text(jumbleOptions ? "Questions and answer choices shuffled each attempt." : "Questions and choices shown in original order.")
                    .font(.caption)
            }

            Section(header: Text("Weeks")) {
                let sortedWeeks = course.questionsByWeek.keys.sorted()
                let allQuestions = sortedWeeks.flatMap { course.questionsByWeek[$0] ?? [] }

                NavigationLink(destination: NPTELWeekQuizView(
                    courseId: course.id,
                    courseName: course.name,
                    week: 0,
                    questions: allQuestions,
                    nextWeekQuestions: nil,
                    nextWeek: nil,
                    immediateFeedback: immediateFeedback,
                    jumbleOptions: jumbleOptions,
                    store: store
                )) {
                    NPTELWeekRow(week: 0, questionCount: allQuestions.count, record: nil, accent: accent)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                ForEach(sortedWeeks, id: \.self) { week in
                    let qs = course.questionsByWeek[week] ?? []
                    let rec = store.record(courseId: course.id, week: week)
                    let nextWeek = sortedWeeks.first(where: { $0 > week })
                    NavigationLink(destination: NPTELWeekQuizView(
                        courseId: course.id,
                        courseName: course.name,
                        week: week,
                        questions: qs,
                        nextWeekQuestions: nextWeek.map { course.questionsByWeek[$0] ?? [] },
                        nextWeek: nextWeek,
                        immediateFeedback: immediateFeedback,
                        jumbleOptions: jumbleOptions,
                        store: store
                    )) {
                        NPTELWeekRow(week: week, questionCount: qs.count, record: rec, accent: accent)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Week Row

private struct NPTELWeekRow: View {
    let week: Int
    let questionCount: Int
    let record: QuizRecord?
    let accent: Color

    private var isAllWeeks: Bool { week == 0 }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accent.opacity(record != nil ? 0.2 : 0.1))
                    .frame(width: 40, height: 40)
                if isAllWeeks {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(accent)
                } else {
                    Text("\(week)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(accent)
                }
            }
            HStack(spacing: 0) {
                Text(isAllWeeks ? "All Weeks" : "Week \(week)")
                    .font(.headline)
                Text("  ·  \(questionCount)Q")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let rec = record {
                scoreChip(score: rec.bestScore, total: rec.totalQuestions)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func scoreChip(score: Int, total: Int) -> some View {
        let pct = total > 0 ? Double(score) / Double(total) : 0
        let color: Color = pct >= 0.8 ? .green : pct >= 0.6 ? .orange : .red
        Text("\(score)/\(total)")
            .font(.caption.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Quiz Session

fileprivate struct NPTELWeekQuizView: View {
    let courseId: String
    let courseName: String
    let week: Int
    let questions: [NPTELQuestion]
    let nextWeekQuestions: [NPTELQuestion]?
    let nextWeek: Int?
    let immediateFeedback: Bool
    let jumbleOptions: Bool
    @ObservedObject var store: NPTELQuizStore

    private var accent: Color { courseAccents[courseId] ?? .blue }

    @State private var currentIndex = 0
    @State private var selectedOptions: [String?] = []
    @State private var score = 0
    @State private var finished = false
    @State private var startTime = Date()
    @State private var elapsedSeconds: Double = 0
    @State private var timer: Timer? = nil
    @State private var shuffledQuestions: [NPTELQuestion] = []

    private var selectedOption: String? { selectedOptions.indices.contains(currentIndex) ? selectedOptions[currentIndex] : nil }

    var body: some View {
        Group {
            if finished {
                NPTELResultView(
                    courseId: courseId,
                    week: week,
                    nextWeek: nextWeek,
                    nextWeekQuestions: nextWeekQuestions,
                    score: score,
                    total: shuffledQuestions.count,
                    timeSeconds: elapsedSeconds,
                    accent: accent,
                    shuffledQuestions: shuffledQuestions,
                    selectedOptions: selectedOptions,
                    store: store,
                    onRetry: restart
                )
            } else if shuffledQuestions.isEmpty {
                Text("No questions available.")
                    .foregroundColor(.secondary)
            } else {
                quizBody
            }
        }
        .navigationTitle(week == 0 ? "All Weeks" : "Week \(week)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !finished {
                    Text(formatTime(elapsedSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(accent)
                }
            }
        }
        .onAppear { restart() }
        .onDisappear { stopTimer() }
    }

    @ViewBuilder
    private var quizBody: some View {
        let q = shuffledQuestions[currentIndex]
        let picked = selectedOption
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Q\(currentIndex + 1) / \(shuffledQuestions.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Score: \(score)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(accent)
                    }
                    ProgressView(value: Double(currentIndex + 1), total: Double(shuffledQuestions.count))
                        .tint(accent)
                }
                .padding(.horizontal)

                Text(q.question)
                    .font(.body.weight(.medium))
                    .padding(.horizontal)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    ForEach(q.options, id: \.self) { option in
                        OptionButton(
                            text: option,
                            state: immediateFeedback && picked != nil ? optionState(option, correct: q.answer, picked: picked) : .neutral,
                            selected: picked == option,
                            accent: accent
                        ) {
                            // In immediate feedback mode, lock selection once picked
                            guard picked == nil || !immediateFeedback else { return }
                            selectedOptions[currentIndex] = option
                        }
                    }
                }
                .padding(.horizontal)

                HStack(spacing: 10) {
                    Button(action: skipAll) {
                        Text("Skip All")
                            .font(.headline)
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .foregroundColor(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button(action: advance) {
                        Text(currentIndex + 1 < shuffledQuestions.count ? "Next" : "See Results")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(accent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
            .padding(.vertical)
        }
    }

    private func skipAll() {
        stopTimer()
        elapsedSeconds = Date().timeIntervalSince(startTime)
        score = zip(shuffledQuestions, selectedOptions).filter { q, ans in ans == q.answer }.count
        store.save(courseId: courseId, week: week, score: score, total: shuffledQuestions.count, timeSeconds: elapsedSeconds)
        finished = true
    }

    private func optionState(_ option: String, correct: String, picked: String?) -> OptionState {
        if option == correct { return .correct }
        if option == picked { return .wrong }
        return .neutral
    }

    private func advance() {
        if currentIndex + 1 < shuffledQuestions.count {
            currentIndex += 1
        } else {
            stopTimer()
            elapsedSeconds = Date().timeIntervalSince(startTime)
            // Recalculate score accurately from stored answers
            score = zip(shuffledQuestions, selectedOptions).filter { q, ans in ans == q.answer }.count
            store.save(courseId: courseId, week: week, score: score, total: shuffledQuestions.count, timeSeconds: elapsedSeconds)
            finished = true
        }
    }

    private func restart() {
        let baseQuestions = jumbleOptions ? questions.shuffled() : questions
        shuffledQuestions = baseQuestions.map { q in
            jumbleOptions ? NPTELQuestion(question: q.question, options: q.options.shuffled(), answer: q.answer) : q
        }
        selectedOptions = Array(repeating: nil, count: shuffledQuestions.count)
        currentIndex = 0
        score = 0
        finished = false
        startTime = Date()
        elapsedSeconds = 0
        startTimer()
    }

    private func startTimer() {
        stopTimer()
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            elapsedSeconds = Date().timeIntervalSince(startTime)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Option Button

private enum OptionState { case neutral, correct, wrong }

private struct OptionButton: View {
    let text: String
    let state: OptionState
    let selected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(foreground)
                    .multilineTextAlignment(.leading)
                Spacer()
                if state != .neutral {
                    Image(systemName: state == .correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(state == .correct ? .green : .red)
                }
            }
            .padding(12)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(border, lineWidth: 1.5)
            )
        }
        .disabled(state == .correct || state == .wrong)
    }

    private var background: Color {
        switch state {
        case .correct: return Color.green.opacity(0.1)
        case .wrong: return Color.red.opacity(0.1)
        case .neutral: return selected ? accent.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground)
        }
    }

    private var foreground: Color {
        switch state {
        case .correct: return .green
        case .wrong: return .red
        case .neutral: return .primary
        }
    }

    private var border: Color {
        switch state {
        case .correct: return .green
        case .wrong: return .red
        case .neutral: return selected ? accent : Color(uiColor: .separator).opacity(0.4)
        }
    }
}

// MARK: - Result View

private struct NPTELResultView: View {
    let courseId: String
    let week: Int
    let nextWeek: Int?
    let nextWeekQuestions: [NPTELQuestion]?
    let score: Int
    let total: Int
    let timeSeconds: Double
    let accent: Color
    let shuffledQuestions: [NPTELQuestion]
    let selectedOptions: [String?]
    @ObservedObject var store: NPTELQuizStore
    let onRetry: () -> Void

    @State private var showShare = false
    @State private var goNextWeek = false
    @AppStorage("nptel_immediate_feedback") private var immediateFeedback = true
    @AppStorage("nptel_jumble_options") private var jumbleOptions = true

    private var skipped: Int { selectedOptions.filter { $0 == nil }.count }
    private var wrong: Int { total - score - skipped }
    private var percentage: Double { total > 0 ? Double(score) / Double(total) : 0 }
    private var gradeColor: Color { percentage >= 0.8 ? .green : percentage >= 0.6 ? .orange : .red }
    private var gradeLabel: String {
        if percentage >= 0.8 { return "Excellent!" }
        if percentage >= 0.6 { return "Good" }
        return "Keep practising"
    }
    private var shareText: String {
        let pct = Int(percentage * 100)
        return "NPTEL Quiz · Week \(week)\nScore: \(score)/\(total) (\(pct)%) · \(wrong) wrong · \(skipped) skipped\nTime: \(formatTime(timeSeconds))\n\nVIT Connect 📚"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Compact header: ring + grade + mini stats side by side
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(gradeColor.opacity(0.15), lineWidth: 10)
                            .frame(width: 90, height: 90)
                        Circle()
                            .trim(from: 0, to: percentage)
                            .stroke(gradeColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 90, height: 90)
                            .animation(.easeOut(duration: 0.8), value: percentage)
                        VStack(spacing: 1) {
                            Text("\(score)/\(total)")
                                .font(.system(size: 18, weight: .bold))
                            Text("\(Int(percentage * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(gradeLabel)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(gradeColor)
                        miniStat(icon: "checkmark.circle.fill", color: .green, label: "\(score) correct")
                        miniStat(icon: "xmark.circle.fill", color: .red, label: "\(wrong) wrong")
                        miniStat(icon: "minus.circle.fill", color: .secondary, label: "\(skipped) skipped")
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // Compact stats row
                if let rec = store.record(courseId: courseId, week: week) {
                    HStack(spacing: 0) {
                        compactStat(icon: "timer", color: .blue, title: "Time", value: formatTime(timeSeconds))
                        Divider().frame(height: 32)
                        compactStat(icon: "trophy.fill", color: .orange, title: "Best", value: "\(rec.bestScore)/\(rec.totalQuestions)")
                        Divider().frame(height: 32)
                        compactStat(icon: "bolt.fill", color: .purple, title: "Best Time", value: formatTime(rec.bestTimeSeconds))
                        Divider().frame(height: 32)
                        compactStat(icon: "arrow.clockwise", color: .teal, title: "Tries", value: "\(rec.attempts)")
                    }
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                } else {
                    HStack(spacing: 0) {
                        compactStat(icon: "timer", color: .blue, title: "Time", value: formatTime(timeSeconds))
                    }
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Three buttons in one row
                HStack(spacing: 10) {
                    if let nw = nextWeek, let nqs = nextWeekQuestions, !nqs.isEmpty {
                        NavigationLink(destination: NPTELWeekQuizView(
                            courseId: courseId,
                            courseName: "",
                            week: nw,
                            questions: nqs,
                            nextWeekQuestions: nil,
                            nextWeek: nil,
                            immediateFeedback: immediateFeedback,
                            jumbleOptions: jumbleOptions,
                            store: store
                        ), isActive: $goNextWeek) { EmptyView() }
                    }

                    Button(action: onRetry) {
                        VStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                                .font(.body.weight(.semibold))
                            Text("Retry")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let nw = nextWeek, let nqs = nextWeekQuestions, !nqs.isEmpty {
                        Button { goNextWeek = true } label: {
                            VStack(spacing: 3) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.body.weight(.semibold))
                                Text("Week \(nw)")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .foregroundColor(accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button { showShare = true } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                            Text("Share")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)

                // Review section
                reviewSection
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ShareSheet(text: shareText)
        }
    }

    private func miniStat(icon: String, color: Color, label: String) -> some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundColor(color)
    }

    private func compactStat(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review")
                .font(.title3.weight(.semibold))
                .padding(.horizontal)

            ForEach(shuffledQuestions.indices, id: \.self) { i in
                let q = shuffledQuestions[i]
                let picked = selectedOptions.indices.contains(i) ? selectedOptions[i] : nil
                let isSkipped = picked == nil
                let isCorrect = picked == q.answer
                let cardColor: Color = isSkipped ? .secondary : isCorrect ? .green : .red

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isSkipped ? "minus.circle.fill" : isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(cardColor)
                        .font(.body)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(i + 1). \(q.question)")
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let picked = picked, !isCorrect {
                            HStack(spacing: 4) {
                                Text("Yours:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(picked)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.red)
                            }
                        }
                        HStack(spacing: 4) {
                            Text(isSkipped ? "Answer:" : "Correct:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(q.answer)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardColor.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Helpers

private func formatTime(_ seconds: Double) -> String {
    let s = Int(seconds)
    if s < 60 { return "\(s)s" }
    return "\(s / 60)m \(s % 60)s"
}
