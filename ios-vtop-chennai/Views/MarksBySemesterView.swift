import SwiftUI

struct MarksBySemesterView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var semesterId: String = ""
    @State private var didLoadPicklist = false
    @State private var pickerPrimed = false

    private var choices: [Semester] { dataManager.marksReportSemesterOptions }

    private var marksSemesterDisplayName: String {
        if semesterId.isEmpty { return "…" }
        return choices.first(where: { $0.id == semesterId })?.name ?? "…"
    }

    private var groupedMarks: [(code: String, rows: [MarkReportRow])] {
        let g = Dictionary(grouping: dataManager.marksReportRows, by: \MarkReportRow.courseCode)
        return g.keys.sorted().map { ($0, g[$0] ?? []) }
    }

    var body: some View {
        List {
            if !choices.isEmpty {
                Section {
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
                    }
                }
            } else {
                Section {
                    Text("No semesters loaded. Sign in to VTOP, sync, then pull to refresh.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if semesterId.isEmpty {
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
                    Section(header: Text(sectionHeader(code: sec.code, rows: sec.rows))
                        .foregroundColor(.indigo)) {
                        ForEach(sec.rows.sorted(by: { $0.markTitle.localizedCaseInsensitiveCompare($1.markTitle) == .orderedAscending })) { row in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(row.markTitle)
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.primary)

                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("Scored \(formatNumber(row.scoredMark)) / \(formatNumber(row.maxMark))")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(Color.green.opacity(0.92))
                                    Text("·")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.secondary)
                                    Text("Weight \(formatNumber(row.weightageMark)) / \(formatNumber(row.weightagePercent))%")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(Color.orange.opacity(0.95))
                                    if !row.status.isEmpty {
                                        Text("·")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.secondary)
                                        Text(row.status)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(statusTextColor(row.status))
                                    }
                                }
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Marks by semester")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if semesterId.isEmpty {
                        reloadPicklist()
                    } else {
                        dataManager.refreshMarksReport(semesterSubId: semesterId, completion: nil)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh marks")
            }
        }
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
            guard !didLoadPicklist else { return }
            didLoadPicklist = true
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
            let c = dataManager.marksReportSemesterOptions
            if semesterId.isEmpty {
                if let sid = dataManager.marksReportSemesterId, c.contains(where: { $0.id == sid }) {
                    semesterId = sid
                } else if let sid = dataManager.selectedSemester?.id, c.contains(where: { $0.id == sid }) {
                    semesterId = sid
                } else if let first = c.first {
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

#Preview {
    NavigationStack {
        MarksBySemesterView()
            .environmentObject(DataManager())
    }
}
