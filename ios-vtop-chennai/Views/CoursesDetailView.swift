import SwiftUI

struct CoursesDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var syncState: DataManagerSyncState

    var body: some View {
        ScrollView {
            if syncState.isLoading && dataManager.courses.isEmpty {
                // Skeleton loading
                LazyVStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonCard()
                    }
                }
                .padding(20)
            } else if dataManager.courses.isEmpty {
                EmptyStateView(
                    icon: "book.closed.fill",
                    message: "No courses available"
                )
                .frame(maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(dataManager.courses) { course in
                        CourseCard(
                            course: course,
                            attendance: dataManager.attendance.first { att in
                                let ac = (att.courseCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                if !ac.isEmpty, ac.caseInsensitiveCompare(course.code.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
                                    return true
                                }
                                return att.courseId == course.id && att.courseId != 0
                            }
                        )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Courses")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await dataManager.refreshCoursesWithAttendance()
        }
    }
}

struct CourseCard: View {
    let course: Course
    let attendance: Attendance?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.title)
                        .vtopFont(size: 17, weight: .semibold)
.lineLimit(2)

                    Text(course.code)
                        .vtopFont(size: 14, weight: .medium)
.foregroundStyle(.secondary)
                }

                Spacer()

                // Type badge
                Text(course.type.rawValue.uppercased())
                    .vtopFont(size: 11, weight: .bold)
.foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(courseTypeColor(course.type))
                    )
            }

            Divider()

            // Details grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DetailItem(icon: "person.fill", label: "Faculty", value: course.faculty, color: .blue)
                DetailItem(icon: "mappin.circle.fill", label: "Venue", value: course.venue, color: .red)
                DetailItem(icon: "star.fill", label: "Credits", value: "\(course.credits)", color: .orange)

                if !course.slots.isEmpty {
                    DetailItem(
                        icon: "clock.fill",
                        label: "Slots",
                        value: course.slots.map { $0.slot }.joined(separator: " + "),
                        color: .purple
                    )
                }
            }

            // Attendance
            if let attendance = attendance {
                Divider()

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Attendance")
                            .vtopFont(size: 13, weight: .medium)
.foregroundStyle(.secondary)

                        Text("\(attendance.percentage)%")
                            .vtopFont(size: 24, weight: .bold)
.foregroundStyle(attendanceColor(attendance.percentage))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Classes")
                            .vtopFont(size: 13, weight: .medium)
.foregroundStyle(.secondary)

                        Text("\(attendance.attended)/\(attendance.total)")
                            .vtopFont(size: 16, weight: .semibold)
}
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func courseTypeColor(_ type: CourseType) -> Color {
        switch type {
        case .theory: return .blue
        case .lab: return .green
        case .project: return .purple
        }
    }

    private func attendanceColor(_ percentage: Int) -> Color {
        switch percentage {
        case 75...: return .green
        case 65..<75: return .orange
        default: return .red
        }
    }
}

struct DetailItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .vtopFont(size: 14)
.foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .vtopFont(size: 11, weight: .medium)
.foregroundStyle(.secondary)

                Text(value)
                    .vtopFont(size: 13, weight: .semibold)
.lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        CoursesDetailView()
            .environmentObject(DataManager())
            .environmentObject(DataManagerSyncState())
    }
}
