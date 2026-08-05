import SwiftUI
import Charts

struct VTOPCockpitCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        systemImage: String,
        tint: Color = .accentColor,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .accessibilityAddTraits(.isHeader)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
        }
    }
}

struct NextClassCockpitCard: View {
    let upcoming: VTOPUpcomingSlot?

    var body: some View {
        NavigationLink(destination: TimetableView()) {
            VTOPCockpitCard(title: "Next class", systemImage: "calendar", tint: .blue) {
                if let upcoming {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(upcoming.course.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text(upcoming.course.code)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            if !upcoming.course.venue.isEmpty {
                                Label(upcoming.course.venue, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(upcoming.startDate, style: .time)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.blue)
                            Text(upcoming.startDate.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Label("No upcoming class found", systemImage: "checkmark.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens your timetable")
    }
}

struct UpcomingExamCockpitCard: View {
    let exams: [Exam]

    private var nextExam: Exam? {
        VTOPCockpitMetrics.nextExam(from: exams)?.exam
    }

    var body: some View {
        NavigationLink(destination: ExamScheduleView()) {
            VTOPCockpitCard(title: "Upcoming exam", systemImage: "calendar.badge.exclamationmark", tint: .orange) {
                if let nextExam, let date = nextExam.startDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(nextExam.courseTitle ?? nextExam.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        HStack(spacing: 10) {
                            Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            if let venue = nextExam.venue, !venue.isEmpty {
                                Label(venue, systemImage: "mappin.and.ellipse")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Label("No upcoming exams found", systemImage: "checkmark.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens your exam schedule")
    }
}

private struct AttendanceChartPoint: Identifiable {
    let id: Int
    let code: String
    let percentage: Int
}

struct AttendanceInsightsCard: View {
    let attendance: [Attendance]
    var threshold: Int = 75
    var showPercentages: Bool = true

    private var points: [AttendanceChartPoint] {
        attendance
            .map { row in
                AttendanceChartPoint(
                    id: row.id,
                    code: row.courseCode?.isEmpty == false ? row.courseCode! : "Course \(row.courseId)",
                    percentage: row.percentage
                )
            }
            .sorted { $0.percentage < $1.percentage }
    }

    private var accessibilitySummary: String {
        guard !points.isEmpty else { return "No attendance data available" }
        let lowest = points.first!
        return "Lowest attendance is \(lowest.percentage) percent for \(lowest.code)."
    }

    var body: some View {
        VTOPCockpitCard(title: "Attendance insights", systemImage: "chart.bar.fill", tint: .green) {
            if points.isEmpty {
                Text("Sync attendance to see course-level risk.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Attendance", point.percentage),
                        y: .value("Course", point.code)
                    )
                    .foregroundStyle(attendanceColor(point.percentage).gradient)
                    .annotation(position: .trailing, alignment: .leading) {
                        if showPercentages {
                            Text("\(point.percentage)%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: [0, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                    }
                }
                .chartYAxis {
                    AxisMarks { AxisValueLabel() }
                }
                .frame(height: min(CGFloat(points.count * 36 + 28), 280))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Attendance chart")
                .accessibilityValue(accessibilitySummary)
            }
        }
    }

    private func attendanceColor(_ percentage: Int) -> Color {
        percentage >= threshold ? .green : (percentage >= max(threshold - 10, 0) ? .orange : .red)
    }
}

private struct MarkChartPoint: Identifiable {
    let id: Int
    let code: String
    let percentage: Double
}

struct MarksInsightsCard: View {
    let marks: [Mark]
    let courses: [Course]
    var showPercentages: Bool = true

    private var points: [MarkChartPoint] {
        let grouped = Dictionary(grouping: marks.compactMap { mark -> (Int, Double)? in
            guard let percentage = mark.scorePercentage else { return nil }
            return (mark.courseId, percentage)
        }, by: \.0)
        return grouped.compactMap { courseId, values in
            guard !values.isEmpty else { return nil }
            let code = courses.first(where: { $0.id == courseId })?.code ?? "Course \(courseId)"
            return MarkChartPoint(id: courseId, code: code, percentage: values.map(\.1).reduce(0, +) / Double(values.count))
        }
        .sorted { $0.code < $1.code }
    }

    var body: some View {
        VTOPCockpitCard(title: "Marks overview", systemImage: "chart.line.uptrend.xyaxis", tint: .purple) {
            if points.isEmpty {
                Text("Sync marks to see component performance.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Course", point.code),
                        y: .value("Score", point.percentage)
                    )
                    .foregroundStyle(.purple.gradient)
                    .annotation(position: .top) {
                        if showPercentages {
                            Text("\(Int(point.percentage.rounded()))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Marks overview chart")
                .accessibilityValue("Average component scores by course")
            }
        }
    }
}
