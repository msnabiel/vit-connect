import SwiftUI

struct PerformanceView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedCourse: Course?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if dataManager.courses.isEmpty {
                        EmptyStateView(
                            icon: "chart.bar.fill",
                            message: "No performance data available"
                        )
                        .padding(.top, 100)
                    } else {
                        // Course selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(dataManager.courses) { course in
                                    CourseButton(
                                        course: course,
                                        grade: dataManager.cumulativeMarks.first(where: { $0.courseCode == course.code })?.grade,
                                        isSelected: selectedCourse?.id == course.id
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedCourse = course
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Display marks for selected course
                        if let course = selectedCourse {
                            VStack(spacing: 20) {
                                // Course header
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(course.title)
                                        .font(.system(size: 20, weight: .bold))

                                    HStack(spacing: 16) {
                                        Label(course.type.rawValue.capitalized, systemImage: "book.fill")
                                        Label(course.faculty, systemImage: "person.fill")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)

                                // Individual marks - using LazyVGrid
                                let courseMarks = dataManager.marks.filter { $0.courseId == course.id }

                                if courseMarks.isEmpty {
                                    EmptyStateView(
                                        icon: "doc.text.fill",
                                        message: "No marks available"
                                    )
                                    .padding(.top, 40)
                                } else {
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 16) {
                                        ForEach(courseMarks) { mark in
                                            CompactMarkCard(mark: mark)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }

                                // Cumulative grade
                                if let cumulative = dataManager.cumulativeMarks.first(where: { $0.courseCode == course.code }) {
                                    CumulativeGradeCard(cumulative: cumulative)
                                        .padding(.horizontal, 20)
                                }
                            }
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)

                                Text("Select a course")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 100)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .refreshable {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    dataManager.refreshMarksForSelectedSemester { cont.resume() }
                }
            }
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
            .vtopNavLeadingIcon()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    TimetableToolbarLink()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    MainSyncToolbarButton()
                }
            }
            .onAppear {
                if selectedCourse == nil, let first = dataManager.courses.first {
                    selectedCourse = first
                }
            }
        }
    }
}

struct CourseButton: View {
    let course: Course
    let grade: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(course.code)
                    .font(.system(size: 13, weight: .semibold))

                if let grade = grade {
                    Text(grade)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? .white : gradeColor(grade))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade.uppercased() {
        case "S", "A": return .green
        case "B", "C": return .orange
        case "D", "E": return .red
        default: return .secondary
        }
    }
}

struct CompactMarkCard: View {
    let mark: Mark

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and status
            VStack(alignment: .leading, spacing: 4) {
                Text(mark.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(mark.status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(mark.status.lowercased() == "present" ? .green : .red)
            }

            Divider()

            // Score
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 2) {
                        Text("\(Int(mark.score))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.accentColor)

                        if let maxScore = mark.maxScore {
                            Text("/\(Int(maxScore))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if let percentage = mark.scorePercentage {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Percent")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        Text("\(Int(percentage))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(percentageColor(percentage))
                    }
                }
            }

            // Weightage
            HStack(spacing: 4) {
                Text("\(mark.weightage, specifier: "%.1f")")
                    .font(.system(size: 12, weight: .semibold))

                if let maxWeightage = mark.maxWeightage {
                    Text("/ \(maxWeightage, specifier: "%.1f") wt")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func percentageColor(_ percentage: Double) -> Color {
        switch percentage {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

struct CumulativeGradeCard: View {
    let cumulative: CumulativeMark

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Final Grade")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                if let grade = cumulative.grade {
                    Text(grade)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(gradeColor(grade))
                }
            }

            Spacer()

            if let percentage = cumulative.totalPercentage {
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Total Score")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("\(Int(percentage))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade.uppercased() {
        case "S", "A": return .green
        case "B", "C": return .orange
        case "D", "E": return .red
        default: return .secondary
        }
    }
}

#Preview {
    NavigationView {
        PerformanceView()
            .environmentObject(AuthenticationViewModel())
            .environmentObject(DataManager())
    }
}
