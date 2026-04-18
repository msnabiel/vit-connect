import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0
    @State private var showSemesterSelection = false
    /// Bumped when the Profile tab is selected so nested `NavigationView` pops back to the profile root.
    @State private var profileTabRootId = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeTabView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            // Attendance Tab
            AttendanceTabView()
                .tabItem {
                    Label("Attendance", systemImage: "calendar.badge.checkmark")
                }
                .tag(1)

            // Marks (full mark report by term; replaces former Performance tab)
            PerformanceTabView()
                .tabItem {
                    Label("Marks", systemImage: "doc.text.magnifyingglass")
                }
                .tag(2)

            // Profile Tab
            ProfileTabView()
                .id(profileTabRootId)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .overlay(alignment: .topLeading) {
            TabBarProfileRootBridge(profileTabIndex: 3) {
                profileTabRootId += 1
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        .environment(\.selectHomeTab) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = 0
            }
        }
        .accentColor(.blue)
        .sheet(isPresented: $showSemesterSelection) {
            SemesterSelectionView()
        }
        .sheet(isPresented: $authViewModel.isBackgroundSync) {
            BackgroundSyncView()
        }
        .overlay(alignment: .bottom) {
            if dataManager.isLoading {
                DataLoadingOverlay(message: dataManager.loadingMessage)
            }
        }
        .onAppear {
            print("⚠️ DEBUG: HomeView onAppear - checking data state")
            print("⚠️ DEBUG: - studentProfile: \(dataManager.studentProfile?.name ?? "nil")")
            print("⚠️ DEBUG: - courses count: \(dataManager.courses.count)")
            print("⚠️ DEBUG: - semesters count: \(dataManager.semesters.count)")
            print("⚠️ DEBUG: - webView available: \(dataManager.getWebView() != nil)")

            // Load cached data from UserDefaults if available
            if dataManager.studentProfile == nil {
                print("⚠️ DEBUG: Loading cached data from UserDefaults")
                dataManager.loadCachedData()
            }

            // Show semester selection if no semester is selected
            if dataManager.selectedSemester == nil && !dataManager.semesters.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showSemesterSelection = true
                }
            }
        }
    }
}

// MARK: - Data Loading Overlay
struct DataLoadingOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
        )
        .padding(.bottom, 100)
    }
}

// MARK: - Home Tab
struct HomeTabView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @State private var currentHour = Calendar.current.component(.hour, from: Date())

    var greeting: String {
        switch currentHour {
        case 5..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }

    var greetingEmoji: String {
        switch currentHour {
        case 5..<12:
            return "🌅"
        case 12..<17:
            return "☀️"
        default:
            return "🌙"
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Greeting Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(greetingEmoji)
                                .font(.system(size: 30))
                                .accessibilityHidden(true)
                            Text(greeting)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        Text(dataManager.studentProfile?.name ?? authViewModel.username)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)

                        if let semester = dataManager.selectedSemester?.name {
                            Text(semester)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                    // Academic Performance Cards
                    HStack(spacing: 12) {
                        // CGPA Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CGPA")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            Text(String(format: "%.2f", dataManager.studentProfile?.cgpa ?? 0.0))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.blue)

                            HStack(spacing: 4) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text("Academic")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)

                        // Credits Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Credits")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            Text(String(format: "%.0f", dataManager.studentProfile?.totalCredits ?? 0.0))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.green)

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                Text("Earned")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Attendance Card
                    NavigationLink(destination: AttendanceDetailView()) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Overall Attendance")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }

                            if !dataManager.attendance.isEmpty {
                                let totalAttended = dataManager.attendance.reduce(0) { $0 + $1.attended }
                                let totalClasses = dataManager.attendance.reduce(0) { $0 + $1.total }
                                let overallPercentage = totalClasses > 0 ? Int(ceil(Double(totalAttended) * 100.0 / Double(totalClasses))) : 0

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(overallPercentage)%")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(overallPercentage >= 75 ? .green : (overallPercentage >= 65 ? .orange : .red))

                                        Text("\(totalAttended)/\(totalClasses) classes")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "calendar.badge.checkmark")
                                        .font(.system(size: 36))
                                        .foregroundColor((overallPercentage >= 75 ? Color.green : (overallPercentage >= 65 ? Color.orange : Color.red)).opacity(0.3))
                                }
                            } else {
                                Text("No attendance data available")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Timetable Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Today's Schedule")
                                .font(.system(size: 17, weight: .semibold))

                            Spacer()

                            NavigationLink(destination: TimetableView()) {
                                HStack(spacing: 4) {
                                    Text("View All")
                                        .font(.system(size: 14, weight: .medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal)

                        if dataManager.timetable.isEmpty {
                            Text("No classes today")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            let today = Calendar.current.component(.weekday, from: Date()) - 1
                            let todaySlots = getTodaySlots(dayIndex: today)

                            if todaySlots.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.green)

                                    Text("No classes scheduled for today!")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(todaySlots.prefix(3)) { slot in
                                        TodaySlotView(slot: slot, dayIndex: today, courses: dataManager.courses)
                                    }

                                    if todaySlots.count > 3 {
                                        NavigationLink(destination: TimetableView()) {
                                            Text("+ \(todaySlots.count - 3) more classes")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.accentColor)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.accentColor, lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.vertical)
            }
            .refreshable {
                dataManager.syncAll()
            }
            .navigationBarTitle("VTOP Chennai", displayMode: .inline)
            .vtopNavLeadingIcon()
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

    private func getTodaySlots(dayIndex: Int) -> [TimetableSlot] {
        return dataManager.timetable.filter { slot in
            let slotCode: String? = {
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
            }()
            return slotCode != nil && !slotCode!.isEmpty
        }
    }
}

// MARK: - Today Slot View
struct TodaySlotView: View {
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

    var typeColor: Color {
        guard let course = matchingCourse else { return .gray }
        switch course.type {
        case .theory: return .blue
        case .lab: return .green
        case .project: return .orange
        }
    }

    var body: some View {
        if let course = matchingCourse {
            HStack(spacing: 12) {
                // Time
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.startTime)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(slot.endTime)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(width: 60, alignment: .leading)

                // Color bar
                Rectangle()
                    .fill(typeColor)
                    .frame(width: 4)
                    .cornerRadius(2)

                // Course details
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    HStack {
                        Label(course.venue, systemImage: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(course.type.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(typeColor.opacity(0.2))
                            .foregroundColor(typeColor)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
    }
}

// MARK: - Timetable Slot View
struct TimetableSlotView: View {
    let time: String
    let course: String
    let room: String
    let type: String

    var typeColor: Color {
        switch type {
        case "Theory":
            return .blue
        case "Lab":
            return .green
        default:
            return .orange
        }
    }

    var body: some View {
        HStack {
            // Time indicator
            VStack(alignment: .leading, spacing: 4) {
                Text(time.components(separatedBy: " - ")[0])
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(time.components(separatedBy: " - ")[1])
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .leading)

            // Colored bar
            Rectangle()
                .fill(typeColor)
                .frame(width: 4)

            // Course details
            VStack(alignment: .leading, spacing: 4) {
                Text(course)
                    .font(.system(size: 16, weight: .semibold))

                HStack {
                    Label(room, systemImage: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(type)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(typeColor.opacity(0.2))
                        .foregroundColor(typeColor)
                        .cornerRadius(6)
                }
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Attendance Tab
struct AttendanceTabView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
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

    var body: some View {
        NavigationStack {
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
                            message: "Sign in, then pull to refresh or use Sync in the toolbar."
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
            .navigationTitle("Attendance")
            .navigationBarTitleDisplayMode(.inline)
            .vtopNavLeadingIcon()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EventHubToolbarLink()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    MainSyncToolbarButton()
                }
            }
            .refreshable {
                if attendanceSemesterId.isEmpty {
                    dataManager.refreshAttendanceOnly()
                } else {
                    dataManager.refreshAttendance(semesterSubId: attendanceSemesterId, continueAfterMarks: false)
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
}

// MARK: - Marks tab (mark report by semester; former Performance tab)
struct PerformanceTabView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationStack {
            MarksBySemesterView()
                .environmentObject(dataManager)
                .vtopNavLeadingIcon()
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
}

// Old placeholder performance tab (keeping for reference)
struct OldPerformanceTabView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    PerformanceCard(
                        courseName: "Computer Networks",
                        courseCode: "CSE3001",
                        cat1: 25,
                        cat2: 23,
                        finalMarks: 48
                    )

                    PerformanceCard(
                        courseName: "Database Management",
                        courseCode: "CSE2004",
                        cat1: 28,
                        cat2: 26,
                        finalMarks: 54
                    )

                    PerformanceCard(
                        courseName: "Software Engineering",
                        courseCode: "CSE3005",
                        cat1: 24,
                        cat2: 27,
                        finalMarks: 51
                    )
                }
                .padding()
            }
            .navigationBarTitle("Performance", displayMode: .large)
        }
    }
}

struct PerformanceCard: View {
    let courseName: String
    let courseCode: String
    let cat1: Int
    let cat2: Int
    let finalMarks: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(courseName)
                .font(.headline)

            Text(courseCode)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                VStack {
                    Text("CAT 1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(cat1)/30")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                VStack {
                    Text("CAT 2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(cat2)/30")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(finalMarks)/60")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Profile Tab
struct ProfileTabView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("vtop_dark_mode") private var darkModeEnabled = false
    @State private var confirmSignOut = false

    var body: some View {
        NavigationView {
            List {
                // Student Info Section
                if let profile = dataManager.studentProfile {
                    Section(header: Text("Student Information")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(profile.name)
                                    .font(.system(size: 18, weight: .bold))

                                if let semester = profile.semester {
                                    Text(semester)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CGPA")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f", profile.cgpa))
                                    .font(.system(size: 16, weight: .semibold))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Credits")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("\(Int(profile.totalCredits))")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("Academic Information")) {
                    NavigationLink(destination: CoursesDetailView().environmentObject(dataManager)) {
                        Label("Courses", systemImage: "book.fill")
                    }

                    NavigationLink(destination: TimetableView().environmentObject(authViewModel).environmentObject(dataManager)) {
                        Label("Timetable", systemImage: "calendar.day.timeline.left")
                    }

                    NavigationLink(destination: GradeHistoryView().environmentObject(dataManager)) {
                        Label("Grade history (all semesters)", systemImage: "chart.bar.doc.horizontal")
                    }

                    NavigationLink(destination: MarksBySemesterView().environmentObject(dataManager)) {
                        Label("Marks by semester", systemImage: "doc.text.magnifyingglass")
                    }

                    NavigationLink(destination: ExamScheduleView().environmentObject(dataManager)) {
                        Label("Exam Schedule", systemImage: "calendar")
                    }

                    NavigationLink(destination: SpotlightView().environmentObject(dataManager)) {
                        Label("Announcements", systemImage: "megaphone.fill")
                    }

                    NavigationLink(destination: EventHubView().environmentObject(dataManager)) {
                        Label("Event hub", systemImage: "calendar.badge.clock")
                    }
                }

                Section(header: Text("Financial & Administrative")) {
                    NavigationLink(destination: ReceiptsView().environmentObject(dataManager)) {
                        Label("Payment Receipts", systemImage: "doc.text.fill")
                    }

                    NavigationLink(destination: StaffInformationView().environmentObject(dataManager)) {
                        Label("Staff Information", systemImage: "person.2.fill")
                    }

                    NavigationLink(destination: PortalCredentialsView().environmentObject(dataManager)) {
                        Label("Portal credentials & rank", systemImage: "key.fill")
                    }
                }

                Section(header: Text("Profile & sync")) {
                    NavigationLink(destination: FullStudentProfileView().environmentObject(dataManager)) {
                        Label("Full profile", systemImage: "person.text.rectangle")
                    }

                    // Replace with your real form URL when ready.
                    Link(destination: URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSf_replaceWithRealFormId/viewform")!) {
                        Label("Bugs & suggestions", systemImage: "ladybug.fill")
                    }

                    Button(action: {
                        authViewModel.triggerSync()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.primary)
                                .rotationEffect(.degrees(dataManager.isLoading ? 360 : 0))
                                .animation(
                                    dataManager.isLoading ?
                                    Animation.linear(duration: 1.0).repeatForever(autoreverses: false) :
                                    .default,
                                    value: dataManager.isLoading
                                )
                            Text(dataManager.isLoading ? "Syncing..." : "Full Sync Data")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .disabled(dataManager.isLoading)

                    Toggle("Dark mode", isOn: $darkModeEnabled)
                }

                Section(header: Text("Legal")) {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy policy", systemImage: "hand.raised.fill")
                    }
                    NavigationLink(destination: TermsAndConditionsView()) {
                        Label("Terms and conditions", systemImage: "doc.plaintext")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmSignOut = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationBarTitle("Profile", displayMode: .inline)
            .alert("Sign out?", isPresented: $confirmSignOut) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
            } message: {
                Text("You will need to sign in again.")
            }
        }
    }
}

#Preview {
    let authViewModel = AuthenticationViewModel()
    let dataManager = DataManager()
    authViewModel.dataManager = dataManager

    return HomeView()
        .environmentObject(authViewModel)
        .environmentObject(dataManager)
}
