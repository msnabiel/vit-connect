import SwiftUI

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

    private static let semesterPickerHorizontalPadding: CGFloat = 16
    private static let semesterPickerTopPadding: CGFloat = 10
    private static let semesterPickerBottomPadding: CGFloat = 8

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
            VStack(spacing: 0) {
                if !choices.isEmpty {
                    Menu {
                        ForEach(choices) { s in
                            Button(s.name) {
                                semesterId = s.id
                                if pickerPrimed {
                                    dataManager.refreshMarksReport(semesterSubId: s.id, completion: nil)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Semester — \(marksSemesterDisplayName)")
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(uiColor: .systemBlue))
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
                    }
                    .padding(.horizontal, Self.semesterPickerHorizontalPadding)
                    .padding(.top, Self.semesterPickerTopPadding)
                    .padding(.bottom, Self.semesterPickerBottomPadding)
                }

                List {
                    if choices.isEmpty {
                        Section {
                            Text("No semesters loaded. Sign in to VTOP, sync, then pull to refresh.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else if semesterId.isEmpty {
                        Section {
                            Text("Select a semester to load mark components.")
                                .foregroundColor(.secondary)
                        }
                    } else if dataManager.marksReportRows.isEmpty {
                        Section {
                            Text("No mark rows for this semester. Tap refresh or try another term.")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(groupedMarks, id: \.code) { sec in
                            let sortedRows = sec.rows.sorted(by: { $0.markTitle.localizedCaseInsensitiveCompare($1.markTitle) == .orderedAscending })
                            let totalScored = sortedRows.reduce(0.0) { $0 + $1.scoredMark }
                            let totalMax = sortedRows.reduce(0.0) { $0 + $1.maxMark }
                            let totalWeightage = sortedRows.reduce(0.0) { $0 + $1.weightageMark }
                            let totalMaxWeightage = sortedRows.reduce(0.0) { $0 + $1.weightagePercent }
                            let weightageProgress = totalMaxWeightage > 0 ? totalWeightage / totalMaxWeightage : 0

                            Section(header: Text(sectionHeader(code: sec.code, rows: sec.rows))
                                .foregroundColor(.indigo)) {
                                ForEach(sortedRows) { row in
                                    MarkRowView(row: row, formatNumber: formatNumber, statusTextColor: statusTextColor)
                                }

                                SubjectTotalFooterView(
                                    totalScored: totalScored,
                                    totalMax: totalMax,
                                    totalWeightage: totalWeightage,
                                    totalMaxWeightage: totalMaxWeightage,
                                    weightageProgress: weightageProgress,
                                    formatNumber: formatNumber
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Marks")
        .navigationBarTitleDisplayMode(.inline)
        .vtopOpaqueNavigationBar()
        .refreshable {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                if semesterId.isEmpty {
                    reloadPicklist { cont.resume() }
                } else {
                    dataManager.refreshMarksReport(semesterSubId: semesterId) { cont.resume() }
                }
            }
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
}

// MARK: - Mark Row

private struct MarkRowView: View {
    let row: MarkReportRow
    let formatNumber: (Double) -> String
    let statusTextColor: (String) -> Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(row.markTitle)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(formatNumber(row.scoredMark)) / \(formatNumber(row.maxMark))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(scoreColor(scored: row.scoredMark, max: row.maxMark))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(scoreColor(scored: row.scoredMark, max: row.maxMark).opacity(0.15))
                    )
            }

            HStack(spacing: 4) {
                Image(systemName: "scalemass.fill")
                    .font(.caption2)
                    .foregroundColor(Color(uiColor: .systemOrange))
                Text("Weightage \(formatNumber(row.weightageMark)) / \(formatNumber(row.weightagePercent))%")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color(uiColor: .systemOrange))
                if !row.status.isEmpty {
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(row.status)
                        .font(.caption.weight(.medium))
                        .foregroundColor(statusTextColor(row.status))
                }
                if let avg = row.classAverage {
                    Spacer()
                    Text("Avg \(formatNumber(avg))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 5)
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
    let formatNumber: (Double) -> String

    private var progressColor: Color {
        if weightageProgress >= 0.75 { return Color(uiColor: .systemGreen) }
        if weightageProgress >= 0.5 { return Color(uiColor: .systemOrange) }
        return Color(uiColor: .systemRed)
    }

    private var percentageText: String {
        if totalMaxWeightage <= 0 { return "—" }
        return String(format: "%.1f%%", weightageProgress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Scored")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(formatNumber(totalScored)) / \(formatNumber(totalMax))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Weightage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(formatNumber(totalWeightage)) / \(formatNumber(totalMaxWeightage))%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                }

                Text(percentageText)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(progressColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(progressColor.opacity(0.15))
                    )
                    .padding(.leading, 8)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(uiColor: .systemFill))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(progressColor)
                        .frame(width: geo.size.width * CGFloat(min(weightageProgress, 1.0)), height: 6)
                        .animation(.easeOut(duration: 0.4), value: weightageProgress)
                }
            }
            .frame(height: 6)
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
}

#Preview {
    NavigationStack {
        MarksBySemesterView()
            .environmentObject(DataManager())
    }
}
