import SwiftUI

// MARK: - UITextField with Done Button for Decimal Pad

struct DecimalTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool
    var placeholder: String
    var onDone: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = .decimalPad
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 15, weight: .semibold)

        // Add toolbar with Done button
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        toolbar.items = [flexSpace, doneButton]
        textField.inputAccessoryView = toolbar

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        if isEditing && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isEditing && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isEditing: $isEditing, onDone: onDone)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isEditing: Bool
        var onDone: () -> Void

        init(text: Binding<String>, isEditing: Binding<Bool>, onDone: @escaping () -> Void) {
            _text = text
            _isEditing = isEditing
            self.onDone = onDone
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        @objc func doneTapped() {
            onDone()
        }
    }
}

struct MarksBySemesterView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var semesterId: String = ""
    @State private var pickerPrimed = false

    /// Prefer options from the marks page (`StudentMarkView`); if that list is empty (session timing, HTML change, or load order), fall back to timetable semesters like the Attendance tab.
    private var choices: [Semester] {
        let fromMarks = dataManager.marksReportSemesterOptions
        if !fromMarks.isEmpty { return fromMarks }
        return dataManager.semesters
    }

    private var marksSemesterDisplayName: String {
        if semesterId.isEmpty { return "…" }
        return choices.first(where: { $0.id == semesterId })?.name ?? "…"
    }

    private var groupedMarks: [(code: String, rows: [MarkReportRow])] {
        let g = Dictionary(grouping: dataManager.marksReportRows, by: \MarkReportRow.courseCode)
        return g.keys.sorted().map { ($0, g[$0] ?? []) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
            VStack(spacing: 0) {
                if !choices.isEmpty {
                    SemesterMenuView(
                        choices: choices,
                        selectedName: marksSemesterDisplayName,
                        tint: Color(uiColor: .systemBlue),
                        onSelect: { semester in
                        semesterId = semester.id
                        if pickerPrimed {
                            dataManager.refreshMarksReport(semesterSubId: semester.id, completion: nil)
                        }
                        }
                    )
                }

                List {
                    if choices.isEmpty {
                        Section {
                            Text("No semesters loaded. Sign in to VTOP, sync, then pull to refresh.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if semesterId.isEmpty {
                        Section {
                            Text("Select a semester to load mark components.")
                                .foregroundStyle(.secondary)
                        }
                    } else if dataManager.marksReportRows.isEmpty {
                        Section {
                            Text("No mark rows for this semester. Tap refresh or try another term.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section {
                            MarksOverviewCard(rows: dataManager.marksReportRows)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        ForEach(groupedMarks, id: \.code) { sec in
                            let sortedRows = sec.rows.sorted(by: { $0.markTitle.localizedCaseInsensitiveCompare($1.markTitle) == .orderedAscending })
                            let totalScored = sortedRows.reduce(0.0) { $0 + $1.scoredMark }
                            let totalMax = sortedRows.reduce(0.0) { $0 + $1.maxMark }
                            let totalWeightage = sortedRows.reduce(0.0) { $0 + $1.weightageMark }
                            let totalMaxWeightage = sortedRows.reduce(0.0) { $0 + $1.weightagePercent }
                            let weightageProgress = totalMaxWeightage > 0 ? totalWeightage / totalMaxWeightage : 0

                            CollapsibleSubjectCardView(
                                courseCode: sec.code,
                                courseTitle: sec.rows.first?.courseTitle ?? "",
                                sortedRows: sortedRows,
                                totalScored: totalScored,
                                totalMax: totalMax,
                                totalWeightage: totalWeightage,
                                totalMaxWeightage: totalMaxWeightage,
                                weightageProgress: weightageProgress,
                                formatNumber: formatNumber,
                                statusTextColor: statusTextColor
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .listSectionSpacing(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Marks")
        .navigationBarTitleDisplayMode(.inline)
        .vtopOpaqueNavigationBar()
        .refreshable {
            await reloadPicklistAsync()
        }
        .onAppear {
            // Always try to refresh the marks picklist when the screen shows (tab revisit after sync, or first open before session was ready).
            reloadPicklist()
        }
    }

    private func statusTextColor(_ status: String) -> Color {
        let s = status.lowercased()
        if s.contains("present") { return Color.blue }
        if s.contains("absent") { return Color.red.opacity(0.9) }
        return Color.secondary
    }

    private func sectionHeader(code: String, rows: [MarkReportRow]) -> String {
        if let t = rows.first?.courseTitle, !t.isEmpty {
            return "\(code) — \(t)"
        }
        return code
    }

    private func formatNumber(_ d: Double) -> String {
        if d.isNaN { return "—" }
        if abs(d.rounded() - d) < 0.001 {
            return String(format: "%.0f", d)
        }
        return String(format: "%.1f", d)
    }

    private func reloadPicklist(completion: (() -> Void)? = nil) {
        dataManager.loadMarksSemesterPicklist {
            let fromMarks = dataManager.marksReportSemesterOptions
            let resolvedChoices = !fromMarks.isEmpty ? fromMarks : dataManager.semesters
            if semesterId.isEmpty {
                if let sid = dataManager.marksReportSemesterId, resolvedChoices.contains(where: { $0.id == sid }) {
                    semesterId = sid
                } else if let sid = dataManager.selectedSemester?.id, resolvedChoices.contains(where: { $0.id == sid }) {
                    semesterId = sid
                } else if let first = resolvedChoices.first {
                    semesterId = first.id
                }
            }
            pickerPrimed = true
            if !semesterId.isEmpty {
                dataManager.refreshMarksReport(semesterSubId: semesterId) {
                    completion?()
                }
            } else {
                completion?()
            }
        }
    }

    private func reloadPicklistAsync() async {
        await dataManager.loadMarksSemesterPicklist()
        let fromMarks = dataManager.marksReportSemesterOptions
        let resolvedChoices = !fromMarks.isEmpty ? fromMarks : dataManager.semesters
        if semesterId.isEmpty {
            if let sid = dataManager.marksReportSemesterId, resolvedChoices.contains(where: { $0.id == sid }) {
                semesterId = sid
            } else if let sid = dataManager.selectedSemester?.id, resolvedChoices.contains(where: { $0.id == sid }) {
                semesterId = sid
            } else if let first = resolvedChoices.first {
                semesterId = first.id
            }
        }
        pickerPrimed = true
        if !semesterId.isEmpty {
            await dataManager.refreshMarksReport(for: semesterId)
        }
    }
}

// MARK: - Collapsible Subject Card

private struct CollapsibleSubjectCardView: View {
    let courseCode: String
    let courseTitle: String
    let sortedRows: [MarkReportRow]
    let totalScored: Double
    let totalMax: Double
    let totalWeightage: Double
    let totalMaxWeightage: Double
    let weightageProgress: Double
    let formatNumber: (Double) -> String
    let statusTextColor: (String) -> Color

    @State private var isExpanded = false

    private var progressColor: Color {
        if weightageProgress >= 0.75 { return Color(uiColor: .systemGreen) }
        if weightageProgress >= 0.5 { return Color(uiColor: .systemOrange) }
        return Color(uiColor: .systemRed)
    }

    private var scorePercentage: Double {
        guard totalMax > 0 else { return 0 }
        return totalScored / totalMax
    }

    private var scoreProgressColor: Color {
        if scorePercentage >= 0.75 { return Color(uiColor: .systemGreen) }
        if scorePercentage >= 0.5 { return Color(uiColor: .systemOrange) }
        return Color(uiColor: .systemRed)
    }

    private var percentageText: String {
        if totalMaxWeightage <= 0 { return "—" }
        return String(format: "%.0f%%", weightageProgress * 100)
    }

    // Calculate average class marks for this subject
    private var averageTotalMarks: Double? {
        let averages = sortedRows.compactMap { row -> Double? in
            row.classAverage ?? UserMarkPreferences.getClassAverage(courseCode: courseCode, markTitle: row.markTitle)
        }
        guard !averages.isEmpty else { return nil }
        return averages.reduce(0, +)
    }

    // Calculate total class average weightage (out of 100)
    private var averageTotalWeightage: Double? {
        guard let avgMarks = averageTotalMarks, totalMax > 0, totalMaxWeightage > 0 else { return nil }
        return (avgMarks / totalMax) * totalMaxWeightage
    }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(sortedRows) { row in
                    MarkRowView(
                        row: row,
                        courseCode: courseCode,
                        formatNumber: formatNumber,
                        statusTextColor: statusTextColor
                    )
                }

                SubjectTotalFooterView(
                    totalScored: totalScored,
                    totalMax: totalMax,
                    totalWeightage: totalWeightage,
                    totalMaxWeightage: totalMaxWeightage,
                    weightageProgress: weightageProgress,
                    averageTotal: averageTotalMarks,
                    averageTotalWeightage: averageTotalWeightage,
                    formatNumber: formatNumber
                )
            } label: {
                VStack(spacing: 8) {
                    // Course header
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(courseCode)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)

                            Text(courseTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        // Weightage badge
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(percentageText)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(progressColor)

                            Text("Weightage")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(uiColor: .quaternarySystemFill))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [progressColor.opacity(0.8), progressColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(min(weightageProgress, 1.0)), height: 4)
                        }
                    }
                    .frame(height: 4)

                    // Stats row
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption2)
                                .foregroundStyle(scoreProgressColor)
                            Text("\(formatNumber(totalScored))/\(formatNumber(totalMax))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "scalemass.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("\(formatNumber(totalWeightage))/\(formatNumber(totalMaxWeightage))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        if let avg = averageTotalMarks {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                Text("Avg \(formatNumber(avg))")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .contentShape(Rectangle())
            .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
        }
    }
}

// MARK: - Mark Row

private struct MarkRowView: View {
    let row: MarkReportRow
    let courseCode: String
    let formatNumber: (Double) -> String
    let statusTextColor: (String) -> Color

    @State private var editingAverage: String = ""
    @State private var isEditingAverage = false
    @State private var savedAverage: Double? = nil

    private var displayedAverage: Double? {
        if let saved = savedAverage { return saved }
        return row.classAverage ?? UserMarkPreferences.getClassAverage(courseCode: courseCode, markTitle: row.markTitle)
    }

    private var scorePercentage: Double {
        guard row.maxMark > 0 else { return 0 }
        return row.scoredMark / row.maxMark
    }

    private var diffFromAverage: Double? {
        guard let avg = displayedAverage else { return nil }
        return row.scoredMark - avg
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(alignment: .top, spacing: 14) {
                // Left: Assessment info
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.markTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)

                    // Compact stats
                    HStack(spacing: 8) {
                        Text("\(formatNumber(row.scoredMark))/\(formatNumber(row.maxMark))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(scoreColor(scored: row.scoredMark, max: row.maxMark))

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(formatNumber(row.weightageMark))/\(formatNumber(row.weightagePercent))%")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        if !row.status.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(row.status)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(statusTextColor(row.status))
                        }
                    }

                    // Class average - inline edit or display
                    if isEditingAverage && row.classAverage == nil {
                        HStack(spacing: 8) {
                            Text("Class avg:")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            DecimalTextField(
                                text: $editingAverage,
                                isEditing: $isEditingAverage,
                                placeholder: "0",
                                onDone: saveAndDismiss
                            )
                            .frame(width: 70, height: 32)
                        }
                    } else if let avg = displayedAverage {
                        Button(action: {
                            if row.classAverage == nil {
                                editingAverage = formatNumber(avg)
                                isEditingAverage = true
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text("Class avg:")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text(formatNumber(avg))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.blue)
                                if row.classAverage == nil {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.body)
                                        .foregroundStyle(.blue.opacity(0.7))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    } else if row.classAverage == nil {
                        Button(action: {
                            editingAverage = ""
                            isEditingAverage = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.body)
                                Text("Add class avg")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }

                Spacer()

                // Right: Performance indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f%%", scorePercentage * 100))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(scoreColor(scored: row.scoredMark, max: row.maxMark))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scorePercentage)

                    if let diff = diffFromAverage {
                        HStack(spacing: 3) {
                            Image(systemName: diff >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(diff >= 0 ? .green : .red)
                            Text(diff >= 0 ? "+\(formatNumber(diff))" : "\(formatNumber(diff))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(diff >= 0 ? .green : .red)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.vertical, 12)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: diffFromAverage != nil)
        }
    }

    private func saveAndDismiss() {
        if editingAverage.isEmpty {
            UserMarkPreferences.setClassAverage(courseCode: courseCode, markTitle: row.markTitle, average: nil)
            savedAverage = nil
        } else if let value = Double(editingAverage), value.isFinite, value >= 0 {
            UserMarkPreferences.setClassAverage(courseCode: courseCode, markTitle: row.markTitle, average: value)
            savedAverage = value
        } else {
            return
        }
        isEditingAverage = false
    }

    private func scoreColor(scored: Double, max: Double) -> Color {
        guard max > 0 else { return .secondary }
        let pct = scored / max
        if pct >= 0.75 { return Color(uiColor: .systemGreen) }
        if pct >= 0.5 { return Color(uiColor: .systemOrange) }
        return Color(uiColor: .systemRed)
    }
}

// MARK: - Subject Total Footer

private struct SubjectTotalFooterView: View {
    let totalScored: Double
    let totalMax: Double
    let totalWeightage: Double
    let totalMaxWeightage: Double
    let weightageProgress: Double
    let averageTotal: Double?
    let averageTotalWeightage: Double?
    let formatNumber: (Double) -> String

    private var scorePercentage: Double {
        guard totalMax > 0 else { return 0 }
        return totalScored / totalMax
    }

    private var progressColor: Color {
        if weightageProgress >= 0.75 { return Color(uiColor: .systemGreen) }
        if weightageProgress >= 0.5 { return Color(uiColor: .systemOrange) }
        return Color(uiColor: .systemRed)
    }

    private var scoreProgressColor: Color {
        if scorePercentage >= 0.75 { return Color(uiColor: .systemGreen) }
        if scorePercentage >= 0.5 { return Color(uiColor: .systemOrange) }
        return Color(uiColor: .systemRed)
    }

    private var diffFromAverage: Double? {
        guard let avg = averageTotal else { return nil }
        return totalScored - avg
    }

    private var diffFromAverageWeightage: Double? {
        guard let avgWeight = averageTotalWeightage else { return nil }
        return totalWeightage - avgWeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Summary stats grid
            VStack(spacing: 12) {
                // Row 1: Scored marks
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundStyle(scoreProgressColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Scored")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text("\(formatNumber(totalScored)) / \(formatNumber(totalMax))")
                                .font(.body.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    }

                    Spacer()

                    Text(String(format: "%.1f%%", scorePercentage * 100))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(scoreProgressColor)
                }

                // Row 2: Weightage
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "scalemass.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Weightage")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text("\(formatNumber(totalWeightage)) / \(formatNumber(totalMaxWeightage))%")
                                .font(.body.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    }

                    Spacer()

                    Text(String(format: "%.1f%%", weightageProgress * 100))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(progressColor)
                }

                // Row 3: Class average weighted score /100 (if available)
                if let avgWeight = averageTotalWeightage {
                    let avgWeightedScore = (avgWeight / totalMaxWeightage) * 100
                    let myWeightedScore = (totalWeightage / totalMaxWeightage) * 100
                    let diffWeighted = myWeightedScore - avgWeightedScore

                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Class Avg /100")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                Text("\(formatNumber(avgWeightedScore)) / 100")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(.primary)
                            }
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: diffWeighted >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.body)
                                .foregroundStyle(diffWeighted >= 0 ? .green : .red)
                            Text(diffWeighted >= 0 ? "+\(formatNumber(diffWeighted))" : "\(formatNumber(diffWeighted))")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(diffWeighted >= 0 ? .green : .red)
                        }
                    }
                }

                // Row 4: Class average marks comparison (if available)
                if let avg = averageTotal, let diff = diffFromAverage {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Class Average")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                Text("\(formatNumber(avg)) / \(formatNumber(totalMax))")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(.primary)
                            }
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: diff >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.body)
                                .foregroundStyle(diff >= 0 ? .green : .red)
                            Text(diff >= 0 ? "+\(formatNumber(diff))" : "\(formatNumber(diff))")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(diff >= 0 ? .green : .red)
                        }
                    }
                }
            }

            // Progress bar with animation
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(uiColor: .quaternarySystemFill))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [progressColor.opacity(0.8), progressColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(min(weightageProgress, 1.0)), height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: weightageProgress)
                }
            }
            .frame(height: 4)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

#Preview {
    NavigationStack {
        MarksBySemesterView()
            .environmentObject(DataManager())
            .environmentObject(DataManagerSyncState())
    }
}
