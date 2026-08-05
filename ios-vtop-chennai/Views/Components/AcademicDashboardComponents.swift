import SwiftUI
import Charts

enum VTOPAttendanceFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case atRisk = "At risk"
    case critical = "Critical"

    var id: Self { self }
}

struct AttendanceOverviewCard: View {
    let attended: Int
    let total: Int
    let target: Int
    let isMasked: Bool

    private var percentage: Int {
        total > 0 ? Int(ceil(Double(attended) * 100 / Double(total))) : 0
    }

    private var status: (title: String, color: Color, icon: String) {
        if percentage >= target { return ("On track", .green, "checkmark.circle.fill") }
        if percentage >= max(target - 10, 0) { return ("At risk", .orange, "exclamationmark.triangle.fill") }
        return ("Critical", .red, "xmark.octagon.fill")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Attendance overview", systemImage: "calendar.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                Label("Target \(target)%", systemImage: "target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(isMasked ? "•••%" : "\(percentage)%")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(isMasked ? .secondary : status.color)
                Spacer()
                Text(isMasked ? "••• / ••• classes" : "\(attended) / \(total) classes")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(uiColor: .tertiarySystemFill))
                    if !isMasked {
                        Capsule()
                            .fill(status.color.gradient)
                            .frame(width: proxy.size.width * min(CGFloat(percentage) / 100, 1))
                        Rectangle()
                            .fill(Color.primary.opacity(0.45))
                            .frame(width: 2, height: 12)
                            .offset(x: proxy.size.width * CGFloat(target) / 100)
                    }
                }
            }
            .frame(height: 8)

            if !isMasked {
                Label(status.title, systemImage: status.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.color)
            }
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

struct AttendanceFilterPicker: View {
    @Binding var selection: VTOPAttendanceFilter

    var body: some View {
        Picker("Attendance filter", selection: $selection) {
            ForEach(VTOPAttendanceFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Attendance course filter")
    }
}

private struct MarksChartPoint: Identifiable {
    let id: String
    let code: String
    let percentage: Double
}

struct MarksOverviewCard: View {
    let rows: [MarkReportRow]

    private var points: [MarksChartPoint] {
        Dictionary(grouping: rows, by: \.courseCode)
            .compactMap { code, courseRows in
                let valid = courseRows.filter { $0.maxMark > 0 }
                guard !valid.isEmpty else { return nil }
                let score = valid.reduce(0.0) { $0 + ($1.scoredMark / $1.maxMark * 100) } / Double(valid.count)
                return MarksChartPoint(id: code, code: code, percentage: score)
            }
            .sorted { $0.percentage > $1.percentage }
    }

    private var overall: Int {
        guard !rows.isEmpty else { return 0 }
        let valid = rows.filter { $0.maxMark > 0 }
        guard !valid.isEmpty else { return 0 }
        return Int((valid.reduce(0.0) { $0 + ($1.scoredMark / $1.maxMark * 100) } / Double(valid.count)).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Performance overview", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(.purple)

            HStack(alignment: .firstTextBaseline) {
                Text("\(overall)%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("average assessment score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if points.isEmpty {
                Text("Assessment data will appear here after a marks sync.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Course", point.code),
                        y: .value("Score", point.percentage)
                    )
                    .foregroundStyle(.purple.gradient)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                    }
                }
                .frame(height: 170)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Average assessment scores by course")
                .accessibilityValue(points.map { "\($0.code) \(Int($0.percentage.rounded())) percent" }.joined(separator: ", "))
            }
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
