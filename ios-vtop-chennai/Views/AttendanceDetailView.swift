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
        }
    }
}

struct AttendanceCard: View {
    let course: Course?
    let attendance: Attendance
    @State private var showCalculator = false

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

            // Calculator Button
            Button(action: {
                showCalculator.toggle()
            }) {
                HStack {
                    Image(systemName: "plus.forwardslash.minus")
                        .font(.system(size: 14))

                    Text(showCalculator ? "Hide Calculator" : "Calculate +1 / +2 Impact")
                        .font(.system(size: 14, weight: .medium))

                    Spacer()

                    Image(systemName: showCalculator ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.accentColor)
                .padding(.vertical, 8)
            }

            // Calculator Section
            if showCalculator {
                AttendanceCalculator(attendance: attendance)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .animation(.easeInOut(duration: 0.3), value: showCalculator)
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

struct AttendanceCalculator: View {
    let attendance: Attendance

    // Calculate what happens if we attend/miss classes
    func calculateNewPercentage(additionalAttended: Int, additionalTotal: Int) -> Int {
        let newAttended = attendance.attended + additionalAttended
        let newTotal = attendance.total + additionalTotal
        guard newTotal > 0 else { return 0 }
        return Int(ceil(Double(newAttended) * 100.0 / Double(newTotal)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What-If Calculator")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)

            // +1 Scenarios
            VStack(spacing: 8) {
                CalculatorRow(
                    scenario: "If you attend next class (+1)",
                    oldPercentage: attendance.percentage,
                    newPercentage: calculateNewPercentage(additionalAttended: 1, additionalTotal: 1),
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                CalculatorRow(
                    scenario: "If you miss next class (+1)",
                    oldPercentage: attendance.percentage,
                    newPercentage: calculateNewPercentage(additionalAttended: 0, additionalTotal: 1),
                    icon: "xmark.circle.fill",
                    color: .red
                )
            }

            Divider()

            // +2 Scenarios
            VStack(spacing: 8) {
                CalculatorRow(
                    scenario: "If you attend next 2 classes (+2)",
                    oldPercentage: attendance.percentage,
                    newPercentage: calculateNewPercentage(additionalAttended: 2, additionalTotal: 2),
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                CalculatorRow(
                    scenario: "If you miss next 2 classes (+2)",
                    oldPercentage: attendance.percentage,
                    newPercentage: calculateNewPercentage(additionalAttended: 0, additionalTotal: 2),
                    icon: "xmark.circle.fill",
                    color: .red
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }
}

struct CalculatorRow: View {
    let scenario: String
    let oldPercentage: Int
    let newPercentage: Int
    let icon: String
    let color: Color

    var percentageChange: Int {
        return newPercentage - oldPercentage
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(scenario)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Text("\(newPercentage)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)

                    Text("(\(percentageChange >= 0 ? "+" : "")\(percentageChange)%)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Trend Arrow
            Image(systemName: percentageChange > 0 ? "arrow.up.right" : (percentageChange < 0 ? "arrow.down.right" : "arrow.right"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(percentageChange > 0 ? .green : (percentageChange < 0 ? .red : .gray))
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    AttendanceDetailView()
        .environmentObject(DataManager())
}
