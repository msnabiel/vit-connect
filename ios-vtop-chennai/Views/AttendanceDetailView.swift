import SwiftUI

struct AttendanceDetailView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if dataManager.attendance.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.exclamationmark",
                            title: "No Attendance Data",
                            message: "Attendance data will appear here once loaded"
                        )
                        .padding()
                    } else {
                        ForEach(dataManager.attendance) { attendance in
                            let course = dataManager.courses.first(where: { $0.code == attendance.courseCode })
                                ?? dataManager.courses.first(where: { $0.id == attendance.courseId })
                            AttendanceCard(course: course, attendance: attendance)
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                dataManager.syncAll()
            }
            .navigationTitle("Attendance")
            .navigationBarTitleDisplayMode(.inline)
            .vtopNavLeadingIcon()
        }
    }
}

struct AttendanceCard: View {
    let course: Course?
    let attendance: Attendance

    private var displayTitle: String {
        course?.title ?? attendance.courseTitle ?? "Course"
    }

    private var displayCode: String {
        course?.code ?? attendance.courseCode ?? "—"
    }

    var attendanceColor: Color {
        switch attendance.attendanceColor {
        case .good: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }

    /// Extra absences (each adds one class to total, attended unchanged) while keeping attendance ≥ 75%.
    private var maxMissesWhileStayingAt75: Int {
        let a = attendance.attended
        let t = attendance.total
        guard t > 0 else { return 0 }
        let raw = Double(a) / 0.75 - Double(t)
        return max(0, Int(floor(raw + 1e-9)))
    }

    private var isBelow75: Bool {
        attendance.percentage < 75
    }

    private var cushionLine: String {
        if attendance.total <= 0 { return "" }
        if isBelow75 {
            return "Below 75%. Attend more to recover; skipping classes will make it harder to reach the bar."
        }
        if maxMissesWhileStayingAt75 == 0 {
            return "At the 75% edge: even one more absence may drop you below 75% (if you don’t attend those classes)."
        }
        let n = maxMissesWhileStayingAt75
        let noun = n == 1 ? "class" : "classes"
        return "You can miss up to \(n) more \(noun) and still stay at or above 75% (assuming you don’t attend any of them)."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Course Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(displayCode)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    if let slot = attendance.slot, !slot.isEmpty {
                        Text("Slot: \(slot)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Percentage Badge
                Text("\(attendance.percentage)%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(attendanceColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(attendanceColor.opacity(0.15))
                    )
            }

            // Attendance Bar
            VStack(spacing: 8) {
                HStack {
                    Text("Attended")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(attendance.attendanceRatio)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(height: 8)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(attendanceColor)
                            .frame(width: geometry.size.width * CGFloat(attendance.percentage) / 100.0, height: 8)
                    }
                }
                .frame(height: 8)
            }

            if let meta = attendanceMetaLine {
                Text(meta)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !cushionLine.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "calendar.badge.minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(attendanceColor)
                        .frame(width: 20, alignment: .center)

                    Text(cushionLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemBackground))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var attendanceMetaLine: String? {
        var parts: [String] = []
        if let t = attendance.courseType, !t.isEmpty { parts.append(t) }
        if let f = attendance.facultySummary, !f.isEmpty { parts.append(f) }
        if let a = attendance.attendanceType, !a.isEmpty { parts.append(a) }
        if let r = attendance.registrationDateText, !r.isEmpty { parts.append("Reg: \(r)") }
        if let d = attendance.attendanceDateText, !d.isEmpty { parts.append("As of: \(d)") }
        if let s = attendance.statusText, !s.isEmpty, s != "-" { parts.append("Status: \(s)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview {
    AttendanceDetailView()
        .environmentObject(DataManager())
}
