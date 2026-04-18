import SwiftUI

struct AttendanceDetailView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @AppStorage(VTOPPrivacyStorage.maskOverallAttendance) private var maskOverallAttendance = false
    @State private var attendanceSemesterId: String = ""
    @State private var didLoadPicklist = false
    @State private var attendancePickerPrimed = false

    private var semesterChoices: [Semester] {
        let fromPage = dataManager.attendanceSemesterOptions
        return fromPage.isEmpty ? dataManager.semesters : fromPage
    }

    private var attendanceSemesterDisplayName: String {
        semesterChoices.first(where: { $0.id == attendanceSemesterId })?.name ?? "Choose semester"
    }

    private var overallAttendanceRollup: (attended: Int, total: Int, pct: Int) {
        let rows = dataManager.attendance
        let a = rows.reduce(0) { $0 + $1.attended }
        let t = rows.reduce(0) { $0 + $1.total }
        let pct = t > 0 ? Int(ceil(Double(a) * 100.0 / Double(t))) : 0
        return (a, t, pct)
    }

    @ViewBuilder
    private var overallAttendanceStrip: some View {
        let r = overallAttendanceRollup
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Overall attendance")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                PrivacyMaskToggleButton(
                    isMasked: $maskOverallAttendance,
                    accessibilityShow: "Show overall attendance",
                    accessibilityHide: "Mask overall attendance"
                )
            }
            HStack(alignment: .firstTextBaseline) {
                Text(maskOverallAttendance ? "•••%" : "\(r.pct)%")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(maskOverallAttendance ? .secondary : (r.pct >= 75 ? Color.green : (r.pct >= 65 ? Color.orange : Color.red)))
                Spacer()
                Text(maskOverallAttendance ? "••• / ••• classes" : "\(r.attended)/\(r.total) classes")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .tertiarySystemFill))
                    if !maskOverallAttendance {
                        Capsule()
                            .fill(r.pct >= 75 ? Color.green : (r.pct >= 65 ? Color.orange : Color.red))
                            .frame(width: max(4, geo.size.width * CGFloat(r.pct) / 100.0))
                    }
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    var body: some View {
        Group {
            if dataManager.attendance.isEmpty {
                VStack(spacing: 0) {
                    if !semesterChoices.isEmpty {
                        Menu {
                            ForEach(semesterChoices) { sem in
                                Button(sem.name) {
                                    attendanceSemesterId = sem.id
                                    if attendancePickerPrimed {
                                        dataManager.refreshAttendance(semesterSubId: sem.id, continueAfterMarks: false)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Semester — \(attendanceSemesterDisplayName)")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Color(uiColor: .systemBlue))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                        }
                        .padding()
                    }

                    Spacer(minLength: 0)

                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: "No attendance yet",
                        message: "Choose a semester above, or pull down to refresh."
                    )

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !semesterChoices.isEmpty {
                            Menu {
                                ForEach(semesterChoices) { sem in
                                    Button(sem.name) {
                                        attendanceSemesterId = sem.id
                                        if attendancePickerPrimed {
                                            dataManager.refreshAttendance(semesterSubId: sem.id, continueAfterMarks: false)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Semester — \(attendanceSemesterDisplayName)")
                                        .font(.body.weight(.medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(Color(uiColor: .systemBlue))
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )
                            }
                        }

                        overallAttendanceStrip

                        ForEach(dataManager.attendance) { attendance in
                            AttendanceCard(
                                course: attendance.matchingCatalogCourse(in: dataManager.courses),
                                attendance: attendance
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable {
            if attendancePickerPrimed, !attendanceSemesterId.isEmpty {
                dataManager.refreshAttendance(semesterSubId: attendanceSemesterId, continueAfterMarks: false)
            } else {
                dataManager.syncAll()
            }
        }
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                TimetableToolbarLink()
                MainSyncToolbarButton()
            }
        }
        .onAppear {
            guard !didLoadPicklist else { return }
            didLoadPicklist = true
            dataManager.loadAttendanceSemesterPicklist {
                let choices = dataManager.attendanceSemesterOptions.isEmpty ? dataManager.semesters : dataManager.attendanceSemesterOptions
                guard !choices.isEmpty else { return }
                if attendanceSemesterId.isEmpty {
                    if let sid = dataManager.selectedSemester?.id, choices.contains(where: { $0.id == sid }) {
                        attendanceSemesterId = sid
                    } else {
                        attendanceSemesterId = choices[0].id
                    }
                }
                attendancePickerPrimed = true
                if !attendanceSemesterId.isEmpty {
                    dataManager.refreshAttendance(semesterSubId: attendanceSemesterId, continueAfterMarks: false)
                }
            }
        }
    }
}

struct AttendanceCard: View {
    let course: Course?
    let attendance: Attendance

    /// Prefer titles from the attendance page; catalog `course` is only a fallback and must not override when `courseId` was a bogus match.
    private var displayTitle: String {
        let fromPage = (attendance.courseTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromPage.isEmpty { return fromPage }
        return course?.title ?? "Course"
    }

    private var displayCode: String {
        let fromPage = (attendance.courseCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromPage.isEmpty { return fromPage }
        return course?.code ?? "—"
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

    private func pctAfterSkips(attended: Int, total: Int, skips: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(max(0, attended - skips)) / Double(total) * 100.0
    }

    /// Closing phrase after the fraction: "at 75%" when ~exactly 75%, else "above"/"below".
    private func thresholdTagline(resultingPercent: Double) -> String {
        if abs(resultingPercent - 75) < 0.055 { return "at 75%" }
        if resultingPercent > 75 { return "above 75%" }
        return "below 75%"
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
            let tag = thresholdTagline(resultingPercent: p)
            return String(
                format: "At the 75%% bar: one more missed class puts you at %.2f%% (%d/%d), %@.",
                p,
                max(0, a - 1),
                t,
                tag
            )
        }
        if maxSkips == 1 {
            let p = pctAfterSkips(attended: a, total: t, skips: 1)
            let tag = thresholdTagline(resultingPercent: p)
            return String(
                format: "You can miss up to 1 more class and stay at %.2f%% (%d/%d), %@.",
                p,
                max(0, a - 1),
                t,
                tag
            )
        }
        let pN = pctAfterSkips(attended: a, total: t, skips: maxSkips)
        let tagN = thresholdTagline(resultingPercent: pN)
        let pOne = pctIfMissOneMore(attended: a, total: t)
        return String(
            format: "You can miss up to %d more classes and stay at %.2f%% (%d/%d), %@. If you miss one, you'd be at %.2f%% (%d/%d).",
            maxSkips,
            pN,
            max(0, a - maxSkips),
            t,
            tagN,
            pOne,
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
