import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0
    @State private var showSemesterSelection = false
    /// Bumped when the Profile tab is selected so nested `NavigationView` pops back to the profile root.
    @State private var profileTabRootId = 0
    @State private var homeTabRootId = 0
    @State private var homeCaptchaText = ""

    private var homeCaptchaSheetBinding: Binding<Bool> {
        Binding(
            get: { authViewModel.showCaptcha && !authViewModel.showReCaptchaWebView },
            set: { newValue in
                if !newValue {
                    authViewModel.showCaptcha = false
                }
            }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeTabView()
                .id(homeTabRootId)
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
            TabBarReselectBridge(handlers: [
                0: { homeTabRootId += 1 },
                3: { profileTabRootId += 1 }
            ])
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
        .sheet(isPresented: homeCaptchaSheetBinding) {
            NavigationStack {
                CaptchaInputView(
                    captchaImage: authViewModel.captchaImage,
                    captchaInput: $homeCaptchaText,
                    embedNavigationWrapper: false,
                    onSubmit: {
                        authViewModel.submitLogin(captchaText: homeCaptchaText)
                        homeCaptchaText = ""
                    },
                    onCancel: {
                        authViewModel.showCaptcha = false
                        authViewModel.isLoading = false
                        authViewModel.isAttemptingSessionRecovery = false
                        homeCaptchaText = ""
                    }
                )
                .navigationTitle("Verification")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            authViewModel.showCaptcha = false
                            authViewModel.isLoading = false
                            authViewModel.isAttemptingSessionRecovery = false
                            homeCaptchaText = ""
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $authViewModel.showReCaptchaWebView) {
            if let webView = authViewModel.getWebView() {
                ReCaptchaView(webView: webView, isPresented: $authViewModel.showReCaptchaWebView)
            }
        }
        .overlay(alignment: .bottom) {
            if dataManager.isLoading {
                DataLoadingOverlay(message: dataManager.loadingMessage)
            } else if authViewModel.isLoading,
                      authViewModel.isAttemptingSessionRecovery,
                      !authViewModel.showCaptcha,
                      !authViewModel.showReCaptchaWebView {
                DataLoadingOverlay(message: "Signing in to VTOP…")
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

    private var line: String {
        let t = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Syncing…" : t
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VTOPSmoothSyncArrow(isRunning: true, font: .system(size: 16, weight: .medium), foreground: .white)
            Text(line)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
        )
        .padding(.bottom, 100)
    }
}

// MARK: - Privacy mask (shared Home + Profile via @AppStorage)

enum VTOPPrivacyStorage {
    static let maskCGPA = "vtop_privacy_mask_cgpa"
    static let maskCredits = "vtop_privacy_mask_credits"
    static let maskOverallAttendance = "vtop_privacy_mask_overall_attendance"
}

struct PrivacyMaskToggleButton: View {
    /// When `true`, the value is shown as dots (masked).
    @Binding var isMasked: Bool
    var accessibilityShow: String
    var accessibilityHide: String

    var body: some View {
        Button {
            isMasked.toggle()
        } label: {
            Image(systemName: isMasked ? "eye" : "eye.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMasked ? accessibilityShow : accessibilityHide)
    }
}

// MARK: - Greeting Banner

private struct GreetingBannerView: View {
    let greeting: String
    let greetingEmoji: String
    let name: String
    let semester: String?
    let hour: Int

    private var gradientColors: [Color] {
        switch hour {
        case 5..<12:
            return [Color(red: 0.27, green: 0.55, blue: 0.98), Color(red: 0.48, green: 0.40, blue: 0.96)]
        case 12..<17:
            return [Color(red: 0.22, green: 0.58, blue: 1.0), Color(red: 0.36, green: 0.44, blue: 0.94)]
        default:
            return [Color(red: 0.15, green: 0.25, blue: 0.72), Color(red: 0.28, green: 0.18, blue: 0.60)]
        }
    }

    private var avatarImage: String {
        switch hour {
        case 5..<12: return "sunrise.fill"
        case 12..<17: return "sun.max.fill"
        default: return "moon.stars.fill"
        }
    }

    private var avatarColors: [Color] {
        switch hour {
        case 5..<12: return [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.9, green: 0.3, blue: 0.15)]
        case 12..<17: return [Color(red: 1.0, green: 0.8, blue: 0.1), Color(red: 1.0, green: 0.5, blue: 0.0)]
        default: return [Color(red: 0.3, green: 0.2, blue: 0.6), Color(red: 0.1, green: 0.05, blue: 0.35)]
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Background gradient
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Decorative clouds
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Group {
                        cloudShape(size: 28, opacity: 0.18, offsetY: -6)
                        cloudShape(size: 22, opacity: 0.13, offsetY: 2)
                    }
                    .padding(.trailing, 100)
                }
                Spacer()
            }

            // VIT clock tower silhouette (right side)
            VITClockTowerShape()
                .fill(Color.white.opacity(0.13))
                .frame(width: 90, height: 110)
                .padding(.trailing, 12)
                .padding(.bottom, 0)

            // Content
            HStack(alignment: .center, spacing: 14) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: avatarColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 58, height: 58)
                    Image(systemName: avatarImage)
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(greeting)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text(greetingEmoji)
                            .font(.system(size: 18))
                    }

                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(1)

                    if let semester {
                        Text(semester)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.22)))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: gradientColors[0].opacity(0.35), radius: 12, y: 4)
    }

    private func cloudShape(size: CGFloat, opacity: Double, offsetY: CGFloat) -> some View {
        Ellipse()
            .fill(Color.white.opacity(opacity))
            .frame(width: size * 2, height: size)
            .offset(y: offsetY)
    }
}

private struct VITClockTowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Base building body
        p.addRect(CGRect(x: w*0.25, y: h*0.55, width: w*0.5, height: h*0.45))
        // Main tower shaft
        p.addRect(CGRect(x: w*0.35, y: h*0.25, width: w*0.30, height: h*0.35))
        // Clock face level
        p.addRect(CGRect(x: w*0.30, y: h*0.18, width: w*0.40, height: h*0.12))
        // Belfry
        p.addRect(CGRect(x: w*0.33, y: h*0.10, width: w*0.34, height: h*0.10))
        // Pointed spire
        p.move(to: CGPoint(x: w*0.50, y: 0))
        p.addLine(to: CGPoint(x: w*0.33, y: h*0.12))
        p.addLine(to: CGPoint(x: w*0.67, y: h*0.12))
        p.closeSubpath()
        // Door arch
        var door = Path()
        door.move(to: CGPoint(x: w*0.42, y: h*1.0))
        door.addLine(to: CGPoint(x: w*0.42, y: h*0.72))
        door.addArc(center: CGPoint(x: w*0.50, y: h*0.72), radius: w*0.08, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        door.addLine(to: CGPoint(x: w*0.58, y: h*1.0))
        p.addPath(door)
        // Windows on tower
        p.addRect(CGRect(x: w*0.42, y: h*0.30, width: w*0.16, height: h*0.10))
        p.addRect(CGRect(x: w*0.42, y: h*0.44, width: w*0.16, height: h*0.08))
        return p
    }
}

// MARK: - Home Tab
struct HomeTabView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @State private var currentHour = Calendar.current.component(.hour, from: Date())
    @AppStorage(VTOPPrivacyStorage.maskCGPA) private var maskCGPA = false
    @AppStorage(VTOPPrivacyStorage.maskCredits) private var maskCredits = false
    @AppStorage(VTOPPrivacyStorage.maskOverallAttendance) private var maskOverallAttendance = false

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
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        OfflineDataBanner(showSyncMetadata: true)
                        // Greeting Banner
                        GreetingBannerView(
                            greeting: greeting,
                            greetingEmoji: greetingEmoji,
                            name: dataManager.studentProfile.map(\.displayNameWithSalutation) ?? authViewModel.username,
                            semester: dataManager.selectedSemester?.name,
                            hour: currentHour
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                    // Academic Performance Cards
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("CGPA")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer(minLength: 4)
                                PrivacyMaskToggleButton(
                                    isMasked: $maskCGPA,
                                    accessibilityShow: "Show CGPA",
                                    accessibilityHide: "Mask CGPA"
                                )
                            }

                            Text(maskCGPA ? "••••" : String(format: "%.2f", dataManager.studentProfile?.cgpa ?? 0.0))
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
                        .background(Color(uiColor: .systemBlue).opacity(0.18))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(0.5), lineWidth: 3))

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Credits")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer(minLength: 4)
                                PrivacyMaskToggleButton(
                                    isMasked: $maskCredits,
                                    accessibilityShow: "Show credits",
                                    accessibilityHide: "Mask credits"
                                )
                            }

                            Text(maskCredits ? "•••" : String(format: "%.0f", dataManager.studentProfile?.totalCredits ?? 0.0))
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
                        .background(Color(uiColor: .systemGreen).opacity(0.18))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.green.opacity(0.5), lineWidth: 3))
                    }
                    .padding(.horizontal)

                    // Attendance Card
                    ZStack(alignment: .topTrailing) {
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
                                        .padding(.trailing, 36)
                                }

                                if !dataManager.attendance.isEmpty {
                                    let totalAttended = dataManager.attendance.reduce(0) { $0 + $1.attended }
                                    let totalClasses = dataManager.attendance.reduce(0) { $0 + $1.total }
                                    let overallPercentage = totalClasses > 0 ? Int(ceil(Double(totalAttended) * 100.0 / Double(totalClasses))) : 0

                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(maskOverallAttendance ? "•••%" : "\(overallPercentage)%")
                                                .font(.system(size: 32, weight: .bold))
                                                .foregroundColor(overallPercentage >= 75 ? .green : (overallPercentage >= 65 ? .orange : .red))

                                            Text(maskOverallAttendance ? "••• / ••• classes" : "\(totalAttended)/\(totalClasses) classes")
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
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)

                        PrivacyMaskToggleButton(
                            isMasked: $maskOverallAttendance,
                            accessibilityShow: "Show overall attendance",
                            accessibilityHide: "Mask overall attendance"
                        )
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                        .zIndex(1)
                    }
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
                    .padding(.bottom, 16)
                }
                .scrollContentBackground(.hidden)
                .refreshable {
                    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                        dataManager.refreshHomeSummary { cont.resume() }
                    }
                }
            }
            .navigationBarTitle("VIT Chennai", displayMode: .inline)
            .vtopNavLeadingIcon()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    TimetableToolbarLink()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    MainSyncToolbarButton()
                }
            }
        }
    }

    /// Only periods that map to a registered course for this weekday (not every empty grid label).
    private func getTodaySlots(dayIndex: Int) -> [TimetableSlot] {
        dataManager.timetable
            .filter { $0.matchingCourse(on: dayIndex, courses: dataManager.courses) != nil }
            .sorted { $0.startTime < $1.startTime }
    }
}

// MARK: - Today Slot View
struct TodaySlotView: View {
    let slot: TimetableSlot
    let dayIndex: Int
    let courses: [Course]

    private var matchingCourse: Course? {
        slot.matchingCourse(on: dayIndex, courses: courses)
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
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
        )
    }

    private static let semesterPickerHorizontalPadding: CGFloat = 16
    private static let semesterPickerTopPadding: CGFloat = 10
    /// Minimal gap between picker and the grouped list (matches Marks density).
    private static let semesterPickerBottomPadding: CGFloat = 2

    @ViewBuilder
    private var semesterPickerMenu: some View {
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
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
            )
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OfflineDataBanner(showSyncMetadata: false)
                ZStack(alignment: .top) {
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea(edges: [.horizontal, .bottom])
                    VStack(spacing: 0) {
                        // Same pattern as Marks: picker outside the List so width matches (insetGrouped + extra row insets was double-narrowing).
                        if !semesterChoices.isEmpty {
                            semesterPickerMenu
                                .buttonStyle(.plain)
                                .padding(.horizontal, Self.semesterPickerHorizontalPadding)
                                .padding(.top, Self.semesterPickerTopPadding)
                                .padding(.bottom, Self.semesterPickerBottomPadding)
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
                                    overallAttendanceStrip
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 10, trailing: 0))
                                .listRowBackground(Color.clear)

                                Section {
                                    ForEach(dataManager.attendance) { attendance in
                                        AttendanceCard(
                                            course: attendance.matchingCatalogCourse(in: dataManager.courses),
                                            attendance: attendance
                                        )
                                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
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
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    if attendancePickerPrimed, !attendanceSemesterId.isEmpty {
                        dataManager.refreshAttendance(semesterSubId: attendanceSemesterId, continueAfterMarks: false) {
                            cont.resume()
                        }
                    } else {
                        dataManager.loadAttendanceSemesterPicklist {
                            cont.resume()
                        }
                    }
                }
            }
            .vtopNavLeadingIcon()
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
}

// MARK: - Marks tab (former Performance tab)
struct PerformanceTabView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OfflineDataBanner(showSyncMetadata: false)
                MarksBySemesterView()
                    .environmentObject(dataManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .vtopOpaqueNavigationBar()
            .vtopNavLeadingIcon()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    TimetableToolbarLink()
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
    @EnvironmentObject var friendsStore: FriendsTimetableStore
    @AppStorage("vtop_dark_mode") private var darkModeEnabled = false
    @AppStorage(VTOPPrivacyStorage.maskCGPA) private var maskCGPA = false
    @AppStorage(VTOPPrivacyStorage.maskCredits) private var maskCredits = false
    @State private var confirmSignOut = false
    @State private var confirmClearCache = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                OfflineDataBanner(showSyncMetadata: false)
                List {
                // Student Info Section
                if let profile = dataManager.studentProfile {
                    Section(header: Text("Student Information")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(profile.displayNameWithSalutation)
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

                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CGPA")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(maskCGPA ? "••••" : String(format: "%.2f", profile.cgpa))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Spacer()
                            PrivacyMaskToggleButton(
                                isMasked: $maskCGPA,
                                accessibilityShow: "Show CGPA",
                                accessibilityHide: "Mask CGPA"
                            )
                        }
                        .padding(.vertical, 2)

                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Credits")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(maskCredits ? "•••" : "\(Int(profile.totalCredits))")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Spacer()
                            PrivacyMaskToggleButton(
                                isMasked: $maskCredits,
                                accessibilityShow: "Show credits",
                                accessibilityHide: "Mask credits"
                            )
                        }
                        .padding(.vertical, 2)

                        if let required = profile.totalCreditsRequired {
                            HStack {
                                Text("Total credits required")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.0f", required))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .padding(.vertical, 2)
                        }

                        if let nonGraded = profile.nonGradedCoreRequirement {
                            HStack {
                                Text("Non-graded core requirement")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.1f", nonGraded))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section(header: Text("Academic Information")) {
                    NavigationLink(destination: CoursesDetailView().environmentObject(dataManager)) {
                        Label("Courses", systemImage: "book.fill")
                    }

                    NavigationLink(destination: GPACalculatorView().environmentObject(dataManager)) {
                        HStack {
                            Label("GPA Calculator", systemImage: "function")
                            Spacer()
                            Text("BETA")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                    }

                    NavigationLink(destination: NotesAndTodosHubView()) {
                        Label("Notes & To-Do", systemImage: "pencil.and.list.clipboard")
                    }

                    NavigationLink(destination: TimetableView().environmentObject(authViewModel).environmentObject(dataManager)) {
                        Label("Timetable", systemImage: "calendar")
                    }

                    NavigationLink(destination: GradeHistoryView().environmentObject(dataManager)) {
                        Label("Grade history (all semesters)", systemImage: "chart.bar.doc.horizontal")
                    }

                    NavigationLink(destination: MarksBySemesterView().environmentObject(dataManager)) {
                        Label("Marks", systemImage: "doc.text.magnifyingglass")
                    }

                    NavigationLink(destination: ExamScheduleView().environmentObject(dataManager)) {
                        Label("Exam Schedule", systemImage: "calendar.and.person")
                    }

                    NavigationLink(destination: EventHubView().environmentObject(dataManager)) {
                        Label("Event hub", systemImage: "calendar.badge.clock")
                    }

                    NavigationLink(destination: NPTELQuizView()) {
                        Label("NPTEL Quiz", systemImage: "brain.head.profile")
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

                Section(header: Text("Profile")) {
                    NavigationLink(destination: FullStudentProfileView().environmentObject(dataManager)) {
                        Label("Full profile", systemImage: "person.text.rectangle")
                    }

                    Link(destination: URL(string: "https://drive.google.com/drive/folders/1Z4tBts_Y55n4m8yRSyV7WzKocVHpi9yC")!) {
                        Label("Study Materials", systemImage: "books.vertical.fill")
                    }
                }

                Section(header: Text("Friends")) {
                    NavigationLink(destination: ImportFriendsTimetableView().environmentObject(friendsStore)) {
                        Label("Import timetable", systemImage: "square.and.arrow.down")
                    }
                    NavigationLink(destination: FriendsTimetableListView().environmentObject(friendsStore)) {
                        Label("Friends timetable", systemImage: "person.2.square.stack")
                    }
                    NavigationLink(destination: CompareTimetablesView().environmentObject(dataManager).environmentObject(friendsStore)) {
                        HStack {
                            Label("Compare timetables", systemImage: "rectangle.2.swap")
                            Spacer()
                            Text("BETA")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section(header: Text("Sync & app")) {
                    if dataManager.lastSuccessfulSyncAt != nil || dataManager.cachePersistedAt != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            if let sync = dataManager.lastSuccessfulSyncAt {
                                Label {
                                    Text("Last successful sync: \(sync.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.subheadline)
                                } icon: {
                                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let cached = dataManager.cachePersistedAt {
                                Label {
                                    Text("Data saved on device: \(cached.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } icon: {
                                    Image(systemName: "internaldrive.fill")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Replace with your real form URL when ready.
                    Link(destination: URL(string: "https://docs.google.com/forms/d/e/1FAIpQLScN1VjOZJ0MqUrADnkt_WkYIclAT3KEpT0XSRa_jptUBAIfSQ/viewform")!) {
                        Label("Bugs & suggestions", systemImage: "ladybug.fill")
                    }

                    Button(action: {
                        authViewModel.triggerSync()
                    }) {
                        HStack(alignment: .center, spacing: 8) {
                            VTOPSmoothSyncArrow(
                                isRunning: dataManager.isLoading,
                                font: .body.weight(.medium),
                                foreground: .primary
                            )
                            Text(dataManager.isLoading ? "Syncing…" : "Full Sync Data")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                        }
                    }
                    .disabled(dataManager.isLoading)

                    Toggle(isOn: $darkModeEnabled) {
                        Label("Dark mode", systemImage: "moon.fill")
                    }

                    NavigationLink(destination: CacheManagementView()) {
                        Label("Cache management", systemImage: "externaldrive.fill")
                    }
                }

                Section(header: Text("Legal")) {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy policy", systemImage: "hand.raised.fill")
                    }
                    NavigationLink(destination: TermsAndConditionsView()) {
                        Label("Terms and conditions", systemImage: "doc.plaintext")
                    }
                }

                Section(header: Text("Upcoming updates")) {
                    Text("VIT Bhopal and VIT Vellore — support coming soon.")
                        .font(.subheadline)
                    Text("Moodle integration — coming soon.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitle("Profile", displayMode: .inline)
            .vtopOpaqueNavigationBar()
            .alert("Sign out?", isPresented: $confirmSignOut) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
            } message: {
                Text("You will need to sign in again. Cached data is cleared only if enabled in Cache management.")
            }
            .alert("Clear cache?", isPresented: $confirmClearCache) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    dataManager.clearCachedVTOPData()
                }
            } message: {
                Text("Removes saved VTOP data from this device (grades, attendance, exam schedule, etc.). You stay signed in; use Full Sync Data to download again.")
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
        .environmentObject(FriendsTimetableStore())
        .environmentObject(NotesAndTodosStore())
}
