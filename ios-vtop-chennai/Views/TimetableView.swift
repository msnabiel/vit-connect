import SwiftUI

struct TimetableView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedDay = Calendar.current.component(.weekday, from: Date()) - 1 // 0 = Sunday

    let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let fullWeekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        VStack(spacing: 0) {
            // Day selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<7) { index in
                        Button(action: {
                            selectedDay = index
                        }) {
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
                    }
                }
                .padding(.horizontal)
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
                        ForEach(dataManager.timetable) { slot in
                            TimetableSlotCard(slot: slot, dayIndex: selectedDay, courses: dataManager.courses)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    dataManager.syncAll()
                }
            }
        }
        .navigationTitle("Timetable")
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

    private func isToday(dayIndex: Int) -> Bool {
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        return today == dayIndex
    }
}

struct TimetableSlotCard: View {
    let slot: TimetableSlot
    let dayIndex: Int
    let courses: [Course]

    var slotCode: String? {
        switch dayIndex {
        case 0: return slot.sunday as? String
        case 1: return slot.monday as? String
        case 2: return slot.tuesday as? String
        case 3: return slot.wednesday as? String
        case 4: return slot.thursday as? String
        case 5: return slot.friday as? String
        case 6: return slot.saturday as? String
        default: return nil
        }
    }

    var matchingCourse: Course? {
        guard let code = slotCode else { return nil }
        return courses.first { course in
            course.slots.contains { $0.slot == code }
        }
    }

    var body: some View {
        if let slotCode = slotCode, !slotCode.isEmpty, let course = matchingCourse {
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
        } else {
            // Empty slot
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTime(slot.startTime))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(formatTime(slot.endTime))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(width: 70, alignment: .leading)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 4)
                    .cornerRadius(2)

                Text("No Class")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
            )
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
