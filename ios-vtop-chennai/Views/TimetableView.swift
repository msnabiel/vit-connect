import SwiftUI
import UIKit

struct TimetableView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager

    /// 0 = Sunday … 6 = Saturday (matches `TimetableSlot` weekday columns).
    @State private var selectedDay = Calendar.current.component(.weekday, from: Date()) - 1
    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented = false
    @State private var shareErrorMessage: String?
    @State private var preparedShareFileURL: URL?

    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Weekday indices starting with **today** on the leading edge (then wrapping Sun→Sat).
    private var orderedWeekdayIndices: [Int] {
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        return (0..<7).map { (today + $0) % 7 }
    }

    private var semesterMenuTitle: String {
        dataManager.selectedSemester?.name ?? "Choose semester"
    }

    var body: some View {
        VStack(spacing: 0) {
            semesterPicker
            weekdayStrip
            timetableContent
        }
        .navigationTitle("Timetable")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    shareTimetable()
                } label: {
                        Image(systemName: "square.and.arrow.up")
                            .accessibilityLabel("Share timetable")
                }
                .accessibilityLabel("Share timetable")
                .disabled(dataManager.timetable.isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                MainSyncToolbarButton()
            }
        }
        .onAppear {
            prepareShareFileIfNeeded()
        }
        .onChange(of: dataManager.timetable) { _, _ in
            prepareShareFileIfNeeded()
        }
        .onChange(of: dataManager.courses) { _, _ in
            prepareShareFileIfNeeded()
        }
        .onChange(of: dataManager.selectedSemester?.id) { _, _ in
            prepareShareFileIfNeeded()
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ActivityViewController(activityItems: shareItems)
        }
        .alert("Unable to share", isPresented: Binding(
            get: { shareErrorMessage != nil },
            set: { if !$0 { shareErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                shareErrorMessage = nil
            }
        } message: {
            Text(shareErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var semesterPicker: some View {
        if !dataManager.semesters.isEmpty {
            SemesterMenuView(
                choices: dataManager.semesters,
                selectedName: semesterMenuTitle,
                tint: Color(uiColor: .systemBlue),
                bottomPadding: 8,
                onSelect: { semester in
                dataManager.refreshTimetableAndCoursesForSemester(semester, completion: nil)
                }
            )
            .padding(.top, 4)
        }
    }

    private var weekdayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(orderedWeekdayIndices, id: \.self) { dayIndex in
                    Button {
                        selectedDay = dayIndex
                    } label: {
                        VStack(spacing: 4) {
                            Text(weekdays[dayIndex])
                                .vtopFont(size: 14, weight: selectedDay == dayIndex ? .bold : .medium)
.foregroundStyle(selectedDay == dayIndex ? .white : .primary)

                            if isToday(dayIndex: dayIndex) {
                                Circle()
                                    .fill(selectedDay == dayIndex ? Color.white : Color.accentColor)
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
                                .fill(selectedDay == dayIndex ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }

    private var timetableContent: some View {
        Group {
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
                    if let sem = dataManager.selectedSemester {
                        await dataManager.refreshTimetableAndCourses(for: sem)
                    } else {
                        await dataManager.refreshSemesterPicklist()
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !dataManager.timetable.isEmpty {
                Text("Share tip: this exports timetable JSON for your friends to import from Profile > Friends.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
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

    private func shareTimetable() {
        if preparedShareFileURL == nil {
            prepareShareFileIfNeeded()
        }
        guard let fileURL = preparedShareFileURL else {
            shareErrorMessage = "Could not prepare timetable JSON."
            return
        }
        shareItems = [fileURL]
        isShareSheetPresented = true
    }

    private func prepareShareFileIfNeeded() {
        let payload = TimetableSharePayload(
            semesterName: dataManager.selectedSemester?.name,
            timetable: dataManager.timetable,
            courses: dataManager.courses
        )
        let registerNumber = dataManager.studentProfile?.registrationNumber?.uppercased()
        DispatchQueue.global(qos: .userInitiated).async {
            let file = TimetableShareCodec.writePayloadFile(payload, filePrefix: registerNumber)
            DispatchQueue.main.async {
                self.preparedShareFileURL = file
            }
        }
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
                        .vtopFont(size: 13, weight: .semibold)
.foregroundStyle(.primary)

                    Text(formatTime(slot.endTime))
                        .vtopFont(size: 13)
.foregroundStyle(.secondary)
                }
                .frame(width: 70, alignment: .leading)

                // Color bar
                Rectangle()
                    .fill(courseColor(for: course.type))
                    .frame(width: 4)
                    .clipShape(.rect(cornerRadius: 2))

                // Course details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(course.title)
                            .vtopFont(size: 16, weight: .semibold)
.foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer()

                        Text(slotCode)
                            .vtopFont(size: 12, weight: .medium)
.foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(courseColor(for: course.type))
                            )
                    }

                    HStack(spacing: 12) {
                        Label(course.venue, systemImage: "mappin.circle.fill")
                            .vtopFont(size: 13)
.foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Text(course.type.rawValue)
                            .vtopFont(size: 12, weight: .medium)
.foregroundStyle(courseColor(for: course.type))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(courseColor(for: course.type).opacity(0.15))
                            )
                    }

                    Text(course.faculty)
                        .vtopFont(size: 12)
.foregroundStyle(.secondary)
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
            .environmentObject(DataManagerSyncState())
    }
}
