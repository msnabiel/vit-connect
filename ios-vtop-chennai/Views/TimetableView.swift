import SwiftUI

struct TimetableView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager

    /// 0 = Sunday … 6 = Saturday (matches `TimetableSlot` weekday columns).
    @State private var selectedDay = Calendar.current.component(.weekday, from: Date()) - 1

    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var semesterMenuTitle: String {
        dataManager.selectedSemester?.name ?? "Choose semester"
    }

    var body: some View {
        VStack(spacing: 0) {
            if !dataManager.semesters.isEmpty {
                Menu {
                    ForEach(dataManager.semesters) { sem in
                        Button(sem.name) {
                            dataManager.refreshTimetableAndCoursesForSemester(sem, completion: nil)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Semester — \(semesterMenuTitle)")
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
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { index in
                        Button {
                            selectedDay = index
                        } label: {
                            VStack(spacing: 4) {
                                Text(weekdays[index])
                                    .font(.system(size: 14, weight: selectedDay == index ? .bold : .medium))
                                    .foregroundColor(selectedDay == index ? .white : .primary)

                                if isToday(dayIndex: index) {
                                    Circle()
                                        .fill(selectedDay == index ? Color.white : Color.accentColor)
                                        .frame(width: 6, height: 6)
                                } else {
                                    Circle()
                                        .fill(Color.clear)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedDay == index ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)

            // Timetable content
            if dataManager.timetable.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No Timetable",
                    message: "Your timetable will appear here once loaded"
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if enrolledSlotsForSelectedDay.isEmpty {
                            Text("No class on this day")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(enrolledSlotsForSelectedDay) { slot in
                                TimetableSlotCard(slot: slot, dayIndex: selectedDay, courses: dataManager.courses)
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                        if let sem = dataManager.selectedSemester {
                            dataManager.refreshTimetableAndCoursesForSemester(sem) {
                                cont.resume()
                            }
                        } else {
                            dataManager.syncAll()
                            cont.resume()
                        }
                    }
                }
            }
        }
        .navigationTitle("Timetable")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                TimetableToolbarLink()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                MainSyncToolbarButton()
            }
        }
    }

    private func isToday(dayIndex: Int) -> Bool {
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        return today == dayIndex
    }

    /// Periods where you have a registered class on the selected day (free grid cells omitted).
    private var enrolledSlotsForSelectedDay: [TimetableSlot] {
        dataManager.timetable
            .filter { $0.matchingCourse(on: selectedDay, courses: dataManager.courses) != nil }
            .sorted { $0.startTime < $1.startTime }
    }
}

struct TimetableSlotCard: View {
    let slot: TimetableSlot
    let dayIndex: Int
    let courses: [Course]

    private var slotCode: String? { slot.slotCode(on: dayIndex) }

    private var matchingCourse: Course? {
        slot.matchingCourse(on: dayIndex, courses: courses)
    }

    var body: some View {
        if let slotCode = slotCode, let course = matchingCourse {
            HStack(spacing: 12) {
                // Time column
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTime(slot.startTime))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(formatTime(slot.endTime))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(width: 70, alignment: .leading)

                // Color bar
                Rectangle()
                    .fill(courseColor(for: course.type))
                    .frame(width: 4)
                    .cornerRadius(2)

                // Course details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(course.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Spacer()

                        Text(slotCode)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(courseColor(for: course.type))
                            )
                    }

                    HStack(spacing: 12) {
                        Label(course.venue, systemImage: "mappin.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Text(course.type.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(courseColor(for: course.type))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(courseColor(for: course.type).opacity(0.15))
                            )
                    }

                    Text(course.faculty)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    private func courseColor(for type: CourseType) -> Color {
        switch type {
        case .theory: return .blue
        case .lab: return .green
        case .project: return .orange
        }
    }

    private func formatTime(_ time: String) -> String {
        // Convert 24h to 12h if needed
        let components = time.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return time
        }

        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}

#Preview {
    NavigationStack {
        TimetableView()
            .environmentObject(AuthenticationViewModel())
            .environmentObject(DataManager())
    }
}
