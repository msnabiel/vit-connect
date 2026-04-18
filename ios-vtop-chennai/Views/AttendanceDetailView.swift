import SwiftUI

struct AttendanceDetailView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        Group {
            if dataManager.attendance.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.exclamationmark",
                    title: "No Attendance Data",
                    message: "Attendance will appear here after it loads from sync."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(dataManager.attendance) { attendance in
                            let course = dataManager.courses.first(where: { $0.code == attendance.courseCode })
                                ?? dataManager.courses.first(where: { $0.id == attendance.courseId })
                            AttendanceCard(course: course, attendance: attendance)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable {
            dataManager.syncAll()
        }
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EventHubToolbarLink()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                MainSyncToolbarButton()
            }
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

    /// Extra missed classes (attended −1 each, total unchanged) while keeping percentage ≥ 75%.
    private var maxSkipsWhileStayingAt75: Int {
        let a = attendance.attended
        let t = attendance.total
        guard t > 0, a > 0 else { return 0 }
        var k = 0
        while a - (k + 1) >= 0 {
            let pct = Double(a - k - 1) / Double(t) * 100.0
            if pct + 1e-6 < 75.0 { break }
            k += 1
        }
        return k
    }

    private func pctIfMissOneMore(attended: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(max(0, attended - 1)) / Double(total) * 100.0
    }

    private var isBelow75: Bool {
        attendance.percentage < 75
    }

    private var cushionLine: String {
        if attendance.total <= 0 { return "" }
        if isBelow75 {
            return "Below 75%. Attend more to recover; skipping classes will make it harder to reach the bar."
        }
        let a = attendance.attended
        let t = attendance.total
        let maxSkips = maxSkipsWhileStayingAt75
        if maxSkips == 0 {
            let p = pctIfMissOneMore(attended: a, total: t)
            return String(
                format: "At the 75%% bar: one more missed class puts you at %.2f%% (%d/%d).",
                p,
                max(0, a - 1),
                t
            )
        }
        let n = maxSkips
        let noun = n == 1 ? "class" : "classes"
        let p = pctIfMissOneMore(attended: a, total: t)
        return String(
            format: "You can miss up to %d more %@ and stay at or above 75%%. If you miss one, you’d be at %.2f%% (%d/%d).",
            n,
            noun,
            p,
            max(0, a - 1),
            t
        )
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
    NavigationStack {
        AttendanceDetailView()
            .environmentObject(AuthenticationViewModel())
            .environmentObject(DataManager())
    }
}
