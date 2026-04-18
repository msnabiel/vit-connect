import SwiftUI

struct GradeHistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""

    private var overviewRows: [GradeHistoryCourseRow] {
        let all = dataManager.gradeHistoryRows
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.courseCode.lowercased().contains(q)
                || ($0.courseTitle ?? "").lowercased().contains(q)
        }
    }

    private struct GradeHistorySectionGroup: Identifiable {
        let id: String
        let title: String
        let rows: [GradeHistoryCourseRow]
    }

    private var grouped: [GradeHistorySectionGroup] {
        let rows = overviewRows
        let order = Dictionary(grouping: rows, by: { $0.sectionTitle })
        return rows.map(\.sectionTitle).uniqued().compactMap { title in
            guard let r = order[title] else { return nil }
            return GradeHistorySectionGroup(id: title, title: title, rows: r)
        }
    }

    private var totalCourses: Int {
        overviewRows.count
    }

    private struct GradeLetterCountRow: Identifiable {
        let id: String
        let grade: String
        let count: Int
    }

    private var gradeLetterCounts: [GradeLetterCountRow] {
        var m: [String: Int] = [:]
        for r in overviewRows {
            let g = r.grade.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if g.isEmpty || g == "-" { continue }
            m[g, default: 0] += 1
        }
        return m.map { GradeLetterCountRow(id: $0.key, grade: $0.key, count: $0.value) }.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.grade < rhs.grade
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchFieldChrome
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

                if !dataManager.gradeHistoryRows.isEmpty {
                    Section(header: Text("Record overview")) {
                        LabeledContent("Courses on record", value: "\(totalCourses)")
                        if !gradeLetterCounts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Grades (count per letter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                compactGradeCountTable
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                }

                if grouped.isEmpty {
                    Section {
                        Text(emptyPlaceholder)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(grouped) { group in
                        Section(header: Text(group.title)) {
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
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Grade history")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchFieldChrome: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Course code or name", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var emptyPlaceholder: String {
        if dataManager.gradeHistoryRows.isEmpty {
            return "No semester tables were detected on the grade history page. CGPA above still reflects the summary from VTOP. Try Sync after results are published."
        }
        return "No courses match your search."
    }

    private var compactGradeCountTable: some View {
        VStack(spacing: 0) {
            ForEach(gradeLetterCounts) { item in
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.grade)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(gradeLetterColor(item.grade))
                            .frame(width: 36, alignment: .leading)
                        Spacer(minLength: 8)
                        Text("\(item.count)")
                            .font(.caption.monospacedDigit())
                    }
                    .padding(.vertical, 3)
                    if item.id != gradeLetterCounts.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func gradeLetterColor(_ grade: String) -> Color {
        switch grade.uppercased() {
        case "S": return Color.green
        case "A", "A+": return Color.blue
        case "B", "B+": return Color.teal
        case "C", "C+": return Color.orange
        case "D", "E": return Color.orange.opacity(0.85)
        case "F", "N", "U", "W": return Color.red.opacity(0.85)
        case "P": return Color.indigo
        default: return Color.accentColor
        }
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
