import SwiftUI

struct GradeHistoryView: View {
    @EnvironmentObject var dataManager: DataManager

    private var grouped: [(section: String, rows: [GradeHistoryCourseRow])] {
        let rows = dataManager.gradeHistoryRows
        let order = Dictionary(grouping: rows, by: { $0.sectionTitle })
        return rows.map(\.sectionTitle).uniqued().compactMap { title in
            guard let r = order[title] else { return nil }
            return (title, r)
        }
    }

    var body: some View {
        List {
            if let profile = dataManager.studentProfile {
                Section(header: Text("CGPA summary")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("CGPA")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f", profile.cgpa))
                                .font(.title2.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Credits earned")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.0f", profile.totalCredits))
                                .font(.title3.bold())
                        }
                    }
                    if let cr = profile.creditsRegistered, cr > 0 {
                        LabeledContent("Credits registered", value: String(format: "%.0f", cr))
                    }
                }
            }

            if grouped.isEmpty {
                Section {
                    Text("No semester tables were detected on the grade history page. CGPA above still reflects the summary from VTOP. Try Sync after results are published.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                    Section(header: Text(group.section)) {
                        ForEach(group.rows) { row in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(row.courseCode)
                                        .font(.headline)
                                    Spacer()
                                    Text(row.grade)
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                }
                                if let title = row.courseTitle, !title.isEmpty {
                                    Text(title)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                if let c = row.credits {
                                    Text(String(format: "Credits: %.1f", c))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let em = row.examMonth, !em.isEmpty {
                                    Text(em)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle("Grade history")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

#Preview {
    NavigationStack {
        GradeHistoryView()
            .environmentObject(DataManager())
    }
}
