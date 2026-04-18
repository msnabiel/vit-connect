import SwiftUI

struct MarksBySemesterView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var semesterId: String = ""
    @State private var didLoadPicklist = false
    @State private var pickerPrimed = false

    private var choices: [Semester] { dataManager.marksReportSemesterOptions }

    private var groupedMarks: [(code: String, rows: [MarkReportRow])] {
        let g = Dictionary(grouping: dataManager.marksReportRows, by: \MarkReportRow.courseCode)
        return g.keys.sorted().map { ($0, g[$0] ?? []) }
    }

    var body: some View {
        List {
            if !choices.isEmpty {
                Section {
                    Picker("Semester", selection: $semesterId) {
                        Text("Choose semester").tag("")
                        ForEach(choices) { s in
                            Text(s.name).tag(s.id)
                        }
                    }
                    .onChange(of: semesterId) { _, newId in
                        guard pickerPrimed, !newId.isEmpty else { return }
                        dataManager.refreshMarksReport(semesterSubId: newId, completion: nil)
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
                    Section(header: Text(sectionHeader(code: sec.code, rows: sec.rows))) {
                        ForEach(sec.rows.sorted(by: { $0.markTitle.localizedCaseInsensitiveCompare($1.markTitle) == .orderedAscending })) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.markTitle)
                                    .font(.subheadline.weight(.semibold))
                                HStack {
                                    Text("Scored \(formatNumber(row.scoredMark)) / \(formatNumber(row.maxMark))")
                                    Spacer()
                                    Text("Weight \(formatNumber(row.weightageMark)) / \(formatNumber(row.weightagePercent))%")
                                        .foregroundColor(.secondary)
                                }
                                .font(.caption)
                                if !row.status.isEmpty {
                                    Text(row.status)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
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
            if semesterId.isEmpty, let first = c.first {
                semesterId = first.id
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
