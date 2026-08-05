import SwiftUI

struct AttendanceDetailView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @AppStorage(VTOPPrivacyStorage.maskOverallAttendance) private var maskOverallAttendance = false
    @State private var attendanceSemesterId: String = ""
    @State private var didLoadPicklist = false
    @State private var attendancePickerPrimed = false
    @State private var attendanceFilter: VTOPAttendanceFilter = .all
    @AppStorage(VTOPPersonalizationPreferences.attendanceThresholdKey) private var attendanceTarget = 75

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

    private var filteredAttendance: [Attendance] {
        dataManager.attendance
            .filter { row in
                switch attendanceFilter {
                case .all: true
                case .atRisk: row.percentage < attendanceTarget && row.percentage >= max(attendanceTarget - 10, 0)
                case .critical: row.percentage < max(attendanceTarget - 10, 0)
                }
            }
            .sorted { $0.percentage < $1.percentage }
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
            if !maskOverallAttendance && r.total > 0 {
                HStack(spacing: 5) {
                    Image(systemName: attendanceFeedbackIcon(pct: r.pct))
                        .font(.caption)
                        .foregroundStyle(attendanceFeedbackColor(pct: r.pct))
                    Text(attendanceFeedbackMessage(pct: r.pct, attended: r.attended, total: r.total))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(attendanceFeedbackColor(pct: r.pct))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
        )
    }

    private func attendanceFeedbackColor(pct: Int) -> Color {
        pct >= 85 ? .green : pct >= 75 ? .green : pct >= 65 ? .orange : .red
    }

    private func attendanceFeedbackIcon(pct: Int) -> String {
        pct >= 85 ? "star.fill" : pct >= 75 ? "checkmark.circle.fill" : pct >= 65 ? "exclamationmark.triangle.fill" : "xmark.circle.fill"
    }

    private func attendanceFeedbackMessage(pct: Int, attended: Int, total: Int) -> String {
        if pct >= 90 { return "Outstanding! Keep it up." }
        if pct >= 85 { return "Great attendance! You're well on track." }
        if pct >= 75 { return "You're doing well. Keep attending!" }
        if pct >= 65 { return "At risk — attend more classes to reach 75%." }
        return "Critical — attendance needs urgent improvement."
    }

    var body: some View {
        VStack(spacing: 0) {
            OfflineDataBanner(showSyncMetadata: false)
            ZStack(alignment: .top) {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea(edges: [.horizontal, .bottom])
                VStack(spacing: 0) {
                    if !semesterChoices.isEmpty {
                        SemesterMenuView(
                            choices: semesterChoices,
                            selectedName: attendanceSemesterDisplayName,
                            tint: Color(uiColor: .systemBlue),
                            bottomPadding: 2,
                            onSelect: { semester in
                            attendanceSemesterId = semester.id
                            if attendancePickerPrimed {
                                dataManager.refreshAttendance(semesterSubId: semester.id, continueAfterMarks: false)
                            }
                            }
                        )
                    }
                    List {
                        if dataManager.attendance.isEmpty {
                            Section {
                                EmptyStateView(
                                    icon: "calendar.badge.exclamationmark",
                                    title: "No attendance yet",
                                    message: semesterChoices.isEmpty
                                        ? "Pull down to refresh, or run a full sync."
                                        : "Choose a semester above, or pull down to refresh."
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            Section {
                                AttendanceOverviewCard(
                                    attended: overallAttendanceRollup.attended,
                                    total: overallAttendanceRollup.total,
                                    target: attendanceTarget,
                                    isMasked: maskOverallAttendance
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 10, trailing: 0))
                            .listRowBackground(Color.clear)

                            Section {
                                AttendanceFilterPicker(selection: $attendanceFilter)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }

                            Section {
                                if filteredAttendance.isEmpty {
                                    Text("No courses match this filter.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 16)
                                        .listRowBackground(Color.clear)
                                } else {
                                    ForEach(filteredAttendance) { attendance in
                                    AttendanceCard(
                                        course: attendance.matchingCatalogCourse(in: dataManager.courses),
                                        attendance: attendance,
                                        target: attendanceTarget
                                    )
                                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .listSectionSpacing(10)
                    .contentMargins(.top, 0, for: .scrollContent)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .vtopOpaqueNavigationBar()
        .refreshable {
            if attendancePickerPrimed, !attendanceSemesterId.isEmpty {
                await dataManager.refreshAttendance(for: attendanceSemesterId)
            } else {
                await dataManager.loadAttendanceSemesterPicklist()
                if !dataManager.attendanceSemesterOptions.isEmpty {
                    attendancePickerPrimed = true
                }
            }
        }
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
    var target: Int = 75

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
        if attendance.percentage >= target { return .green }
        if attendance.percentage >= max(target - 10, 0) { return .orange }
        return .red
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
                        .vtopFont(size: 17, weight: .semibold)
.foregroundStyle(.primary)

                    Text(displayCode)
                        .vtopFont(size: 14)
.foregroundStyle(.secondary)

                    if let slot = attendance.slot, !slot.isEmpty {
                        Text("Slot: \(slot)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Percentage Badge
                Text("\(attendance.percentage)%")
                    .vtopFont(size: 20, weight: .bold)
.foregroundStyle(attendanceColor)
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
                        .vtopFont(size: 13, weight: .medium)
.foregroundStyle(.secondary)

                    Spacer()

                    Text(attendance.attendanceRatio)
                        .vtopFont(size: 13, weight: .semibold)
.foregroundStyle(.primary)
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
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !cushionLine.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "calendar.badge.minus")
                        .vtopFont(size: 14, weight: .semibold)
.foregroundStyle(attendanceColor)
                        .frame(width: 20, alignment: .center)

                    Text(cushionLine)
                        .vtopFont(size: 13, weight: .medium)
.foregroundStyle(.primary)
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
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
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
            .environmentObject(DataManagerSyncState())
    }
}
