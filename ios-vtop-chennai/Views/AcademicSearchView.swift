import SwiftUI

struct AcademicSearchView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private enum ResultKind {
        case course, mark, exam, announcement
        var icon: String {
            switch self {
            case .course: "book.fill"
            case .mark: "doc.text.magnifyingglass"
            case .exam: "calendar.badge.exclamationmark"
            case .announcement: "megaphone.fill"
            }
        }
    }

    private struct SearchResult: Identifiable {
        let id: String
        let title: String
        let detail: String
        let kind: ResultKind
    }

    private var results: [SearchResult] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return [] }
        var output: [SearchResult] = []
        output += dataManager.courses.filter { $0.code.lowercased().contains(term) || $0.title.lowercased().contains(term) }.map {
            SearchResult(id: "course-\($0.id)", title: $0.code, detail: $0.title, kind: .course)
        }
        output += dataManager.marks.filter { $0.title.lowercased().contains(term) }.map {
            SearchResult(id: "mark-\($0.id)", title: $0.title, detail: "Assessment mark", kind: .mark)
        }
        output += dataManager.exams.filter {
            ($0.title + " " + ($0.courseCode ?? "") + " " + ($0.courseTitle ?? "")).lowercased().contains(term)
        }.map {
            SearchResult(id: "exam-\($0.id)", title: $0.courseCode ?? $0.title, detail: $0.courseTitle ?? "Exam schedule", kind: .exam)
        }
        output += dataManager.spotlights.filter { $0.announcement.lowercased().contains(term) || $0.category.lowercased().contains(term) }.map {
            SearchResult(id: "announcement-\($0.id)", title: $0.category, detail: $0.announcement, kind: .announcement)
        }
        return output
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    ContentUnavailableView("Search VIT Connect", systemImage: "magnifyingglass", description: Text("Find courses, marks, exams, and announcements."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(results) { result in
                        NavigationLink {
                            destination(for: result.kind)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.title)
                                        .font(.body.weight(.semibold))
                                    Text(result.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            } icon: {
                                Image(systemName: result.kind.icon)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Courses, marks, exams…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for kind: ResultKind) -> some View {
        switch kind {
        case .course: CoursesDetailView().environmentObject(dataManager)
        case .mark: MarksBySemesterView().environmentObject(dataManager)
        case .exam: ExamScheduleView().environmentObject(dataManager)
        case .announcement: SpotlightView().environmentObject(dataManager)
        }
    }
}
