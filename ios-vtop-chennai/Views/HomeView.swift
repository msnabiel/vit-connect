import SwiftUI
import Combine

@MainActor
private enum VTOPShareSheetPresenter {
    static func presentAppShareSheet() {
        let activityVC = UIActivityViewController(
            activityItems: [URL(string: "https://apps.apple.com/us/app/vit-connect/id6764813035")!],
            applicationActivities: nil
        )

        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first,
              let rootViewController = window.rootViewController else { return }

        let presenter = topViewController(from: rootViewController)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }

    private static func topViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = viewController as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = viewController as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return viewController
    }
}

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var syncState: DataManagerSyncState
    @State private var selectedTab = 0
    @State private var showSemesterSelection = false
    /// Bumped when the Profile tab is selected so nested `NavigationStack` pops back to the profile root.
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
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeTabView()
                    .id(homeTabRootId)
            }

            // Attendance Tab
            Tab("Attendance", systemImage: "calendar.badge.checkmark", value: 1) {
                AttendanceTabView()
            }

            // Marks (full mark report by term; replaces former Performance tab)
            Tab("Marks", systemImage: "doc.text.magnifyingglass", value: 2) {
                PerformanceTabView()
            }

            // Games
            Tab("Games", systemImage: "gamecontroller.fill", value: 4) {
                GamesView()
            }

            // Profile Tab
            Tab("Profile", systemImage: "person.fill", value: 3) {
                ProfileTabView()
                    .id(profileTabRootId)
            }
        }
        .environment(\.selectHomeTab, $selectedTab)
        .tint(.blue)
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
        .onOpenURL { url in
            guard let route = VTOPDeepLinkRoute(url: url) else { return }
            switch route {
            case .home:
                selectedTab = 0
                homeTabRootId += 1
            case .attendance:
                selectedTab = 1
            case .marks:
                selectedTab = 2
            case .timetable, .exams, .events:
                selectedTab = 3
                profileTabRootId += 1
            }
        }
        .overlay(alignment: .bottom) {
            if syncState.isLoading {
                DataLoadingOverlay(message: syncState.loadingMessage)
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
                .vtopFont(size: 15, weight: .medium)
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
                .vtopFont(size: 14, weight: .semibold)
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
        case 5..<12: return [Color(red: 0.95, green: 0.82, blue: 0.32), Color(red: 0.80, green: 0.62, blue: 0.12)]
        case 12..<17: return [Color(red: 0.92, green: 0.80, blue: 0.28), Color(red: 0.78, green: 0.64, blue: 0.10)]
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
                        .vtopFont(size: 26)
.foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(greeting)
                            .vtopFont(size: 20, weight: .bold)
.foregroundStyle(.white)
                        Text(greetingEmoji)
                            .vtopFont(size: 18)
}

                    Text(name)
                        .vtopFont(size: 14, weight: .medium)
.foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)

                    if let semester {
                        Text(semester)
                            .vtopFont(size: 12, weight: .medium)
.foregroundStyle(.white.opacity(0.95))
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
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 4)
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
    @EnvironmentObject var syncState: DataManagerSyncState
    @State private var showAcademicSearch = false
    @State private var currentHour = Calendar.current.component(.hour, from: Date())
    private let foregroundPublisher = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
    @AppStorage(VTOPPrivacyStorage.maskCGPA) private var maskCGPA = false
    @AppStorage(VTOPPrivacyStorage.maskCredits) private var maskCredits = false
    @AppStorage(VTOPPrivacyStorage.maskOverallAttendance) private var maskOverallAttendance = false
    @AppStorage(VTOPPersonalizationPreferences.dashboardLayoutKey) private var dashboardLayoutRaw = VTOPPersonalizationPreferences.DashboardLayout.standard.rawValue
    @AppStorage(VTOPPersonalizationPreferences.visibleCardsKey) private var visibleCardsRaw = VTOPPersonalizationPreferences.DashboardCard.allCases.map(\.rawValue).joined(separator: ",")
    @AppStorage(VTOPPersonalizationPreferences.attendanceThresholdKey) private var attendanceThreshold = 75
    @AppStorage(VTOPPersonalizationPreferences.showPercentagesKey) private var showPercentages = true

    private var dashboardLayout: VTOPPersonalizationPreferences.DashboardLayout {
        .init(rawValue: dashboardLayoutRaw) ?? .standard
    }
    private var visibleCards: Set<VTOPPersonalizationPreferences.DashboardCard> {
        Set(visibleCardsRaw.split(separator: ",").compactMap { VTOPPersonalizationPreferences.DashboardCard(rawValue: String($0)) })
    }

    private func shareApp() {
        VTOPShareSheetPresenter.presentAppShareSheet()
    }

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

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: dashboardLayout.spacing) {
                        OfflineDataBanner(showSyncMetadata: true)
                        // Greeting Banner
                        TodayCard(
                            greeting: greeting,
                            name: dataManager.studentProfile?.name ?? authViewModel.username,
                            semester: dataManager.selectedSemester?.name,
                            hour: currentHour
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                        Button {
                            showAcademicSearch = true
                        } label: {
                            Label("Search courses, marks, exams and more", systemImage: "magnifyingglass")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background(.background, in: .rect(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08))
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Search academic data")
                        .padding(.horizontal, 16)

                        // Career banner
                        Link(destination: URL(string: "https://apps.apple.com/us/app/openrole-ai-job-search/id6775263884")!) {
                            HStack(spacing: 10) {
                                Image(systemName: "briefcase.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                                Text("Looking for internships? Try OpenRole")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.05), in: .rect(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.blue.opacity(0.15), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)

                        if syncState.isLoading && dataManager.studentProfile == nil {
                            HomeSkeletonView()
                        }

                        if dataManager.studentProfile != nil {
                            GradeTargetCard()
                                .environmentObject(dataManager)
                                .padding(.horizontal, 16)
                        }

                        if visibleCards.contains(.nextClass) {
                            NextClassCockpitCard(
                                upcoming: VTOPScheduleEngine.nextUpcomingSlot(
                                    timetable: dataManager.timetable,
                                    courses: dataManager.courses
                                )
                            )
                            .padding(.horizontal, 16)
                        }

                        if visibleCards.contains(.exams) {
                            UpcomingExamCockpitCard(exams: dataManager.exams)
                                .padding(.horizontal, 16)
                        }

                        if visibleCards.contains(.attendance) {
                            AttendanceInsightsCard(
                                attendance: dataManager.attendance,
                                threshold: attendanceThreshold,
                                showPercentages: showPercentages
                            )
                            .padding(.horizontal, 16)
                        }

                        if visibleCards.contains(.marks) {
                            MarksInsightsCard(
                                marks: dataManager.marks,
                                courses: dataManager.courses,
                                showPercentages: showPercentages
                            )
                            .padding(.horizontal, 16)
                        }

                    // Academic Performance Cards
                    HStack(spacing: 12) {
                        // CGPA Card
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color.blue.opacity(0.16))
                                .frame(width: 80, height: 80)
                                .offset(x: 18, y: 18)
                            Circle()
                                .fill(Color.blue.opacity(0.11))
                                .frame(width: 50, height: 50)
                                .offset(x: 2, y: 8)

                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.13))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "person.text.rectangle.fill")
                                            .vtopFont(size: 15, weight: .semibold)
.foregroundStyle(.blue)
                                    }
                                    Spacer()
                                    PrivacyMaskToggleButton(
                                        isMasked: $maskCGPA,
                                        accessibilityShow: "Show CGPA",
                                        accessibilityHide: "Mask CGPA"
                                    )
                                }
                                .padding(.bottom, 10)

                                Text(maskCGPA ? "••••" : String(format: "%.2f", dataManager.studentProfile?.cgpa ?? 0.0))
                                    .vtopFont(size: 30, weight: .bold, design: .rounded)
.foregroundStyle(.primary)

                                Text("CGPA")
                                    .vtopFont(size: 12, weight: .semibold)
.foregroundStyle(.secondary)
                                    .padding(.top, 2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.blue.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        // Credits Card
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color.green.opacity(0.16))
                                .frame(width: 80, height: 80)
                                .offset(x: 18, y: 18)
                            Circle()
                                .fill(Color.green.opacity(0.11))
                                .frame(width: 50, height: 50)
                                .offset(x: 2, y: 8)

                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green.opacity(0.13))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "checkmark.seal.fill")
                                            .vtopFont(size: 15, weight: .semibold)
.foregroundStyle(.green)
                                    }
                                    Spacer()
                                    PrivacyMaskToggleButton(
                                        isMasked: $maskCredits,
                                        accessibilityShow: "Show credits",
                                        accessibilityHide: "Mask credits"
                                    )
                                }
                                .padding(.bottom, 10)

                                Text(maskCredits ? "•••" : String(format: "%.0f", dataManager.studentProfile?.totalCredits ?? 0.0))
                                    .vtopFont(size: 30, weight: .bold, design: .rounded)
.foregroundStyle(.primary)

                                Text("Credits")
                                    .vtopFont(size: 12, weight: .semibold)
.foregroundStyle(.secondary)
                                    .padding(.top, 2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.green.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.green.opacity(0.35), lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal)

                    // Attendance Card
                    NavigationLink(destination: AttendanceDetailView()) {
                        let totalAttended = dataManager.attendance.reduce(0) { $0 + $1.attended }
                        let totalClasses = dataManager.attendance.reduce(0) { $0 + $1.total }
                        let overallPercentage = totalClasses > 0 ? Int(ceil(Double(totalAttended) * 100.0 / Double(totalClasses))) : 0
                        let attColor: Color = overallPercentage >= 75 ? .green : (overallPercentage >= 65 ? .orange : .red)
                        let statusLabel = overallPercentage >= 75 ? "On track" : overallPercentage >= 65 ? "At risk" : "Critical"

                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "calendar.badge.checkmark")
                                .vtopFont(size: 70, weight: .regular)
.foregroundStyle(attColor.opacity(0.11))
                                .offset(x: -16, y: 10)

                            VStack(alignment: .leading, spacing: 10) {
                                // Header: icon + title + eye + chevron all in one row
                                HStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(attColor.opacity(0.13))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "calendar.badge.checkmark")
                                            .vtopFont(size: 14, weight: .semibold)
.foregroundStyle(attColor)
                                    }
                                    Text("Overall Attendance")
                                        .vtopFont(size: 14, weight: .semibold)
.foregroundStyle(.primary)
                                    Spacer()
                                    PrivacyMaskToggleButton(
                                        isMasked: $maskOverallAttendance,
                                        accessibilityShow: "Show overall attendance",
                                        accessibilityHide: "Mask overall attendance"
                                    )
                                    Image(systemName: "chevron.right")
                                        .vtopFont(size: 12, weight: .semibold)
.foregroundStyle(Color(uiColor: .tertiaryLabel))
                                }

                                if !dataManager.attendance.isEmpty {
                                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                                        Text(maskOverallAttendance ? "–" : "\(overallPercentage)%")
                                            .vtopFont(size: 40, weight: .bold, design: .rounded)
.foregroundStyle(attColor)

                                        if !maskOverallAttendance && totalClasses > 0 {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(statusLabel)
                                                    .vtopFont(size: 11, weight: .bold)
.foregroundStyle(attColor)
                                                    .padding(.horizontal, 9)
                                                    .padding(.vertical, 3)
                                                    .background(Capsule().fill(attColor.opacity(0.13)))
                                                Text("\(totalAttended) / \(totalClasses) classes")
                                                    .vtopFont(size: 12, weight: .medium)
.foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }

                                    if !maskOverallAttendance && totalClasses > 0 {
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(Color(uiColor: .quaternarySystemFill))
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [attColor.opacity(0.9), attColor.opacity(0.6)],
                                                            startPoint: .leading, endPoint: .trailing
                                                        )
                                                    )
                                                    .frame(width: max(6, geo.size.width * CGFloat(overallPercentage) / 100.0))
                                            }
                                        }
                                        .frame(height: 6)
                                    }
                                } else {
                                    Text("No attendance data")
                                        .vtopFont(size: 14)
.foregroundStyle(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color(uiColor: .separator).opacity(0.4), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Timetable Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Today's Schedule")
                                .vtopFont(size: 17, weight: .semibold)
                            Spacer()

                            NavigationLink(destination: TimetableView()) {
                                HStack(spacing: 4) {
                                    Text("View All")
                                        .vtopFont(size: 14, weight: .medium)
Image(systemName: "chevron.right")
                                        .vtopFont(size: 12, weight: .semibold)
}
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal)

                        if dataManager.timetable.isEmpty {
                            Text("No classes today")
                                .vtopFont(size: 15)
.foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            let today = Calendar.current.component(.weekday, from: Date()) - 1
                            let todaySlots = getTodaySlots(dayIndex: today)

                            if todaySlots.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .vtopFont(size: 20)
.foregroundStyle(.green)

                                    Text("No classes scheduled for today!")
                                        .vtopFont(size: 15)
.foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green.opacity(0.1))
                                .clipShape(.rect(cornerRadius: 12))
                                .padding(.horizontal)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(todaySlots.prefix(3)) { slot in
                                        TodaySlotView(slot: slot, dayIndex: today, courses: dataManager.courses)
                                    }

                                    if todaySlots.count > 3 {
                                        NavigationLink(destination: TimetableView()) {
                                            Text("+ \(todaySlots.count - 3) more classes")
                                                .vtopFont(size: 14, weight: .medium)
.foregroundStyle(Color.accentColor)
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
                    await dataManager.refreshHomeSummary()
                }
            }
            .onReceive(foregroundPublisher) { _ in
                currentHour = Calendar.current.component(.hour, from: Date())
            }
            .navigationTitle("VIT Chennai")
            .navigationBarTitleDisplayMode(.inline)
            .vtopNavLeadingIcon()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareApp) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share app")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    TimetableToolbarLink()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    MainSyncToolbarButton()
                }
            }
            .sheet(isPresented: $showAcademicSearch) {
                AcademicSearchView()
                    .environmentObject(dataManager)
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
                        .vtopFont(size: 12, weight: .semibold)
.foregroundStyle(.secondary)

                    Text(slot.endTime)
                        .vtopFont(size: 12)
.foregroundStyle(.secondary)
                }
                .frame(width: 60, alignment: .leading)

                // Color bar
                Rectangle()
                    .fill(typeColor)
                    .frame(width: 4)
                    .clipShape(.rect(cornerRadius: 2))

                // Course details
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .vtopFont(size: 15, weight: .semibold)
.lineLimit(1)

                    HStack {
                        Label(course.venue, systemImage: "mappin.circle.fill")
                            .vtopFont(size: 12)
.foregroundStyle(.secondary)

                        Spacer()

                        Text(course.type.rawValue)
                            .vtopFont(size: 11, weight: .medium)
.padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(typeColor.opacity(0.2))
                            .foregroundStyle(typeColor)
                            .clipShape(.rect(cornerRadius: 4))
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 10))
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
                    .vtopFont(size: 12, weight: .semibold)
.foregroundStyle(.secondary)

                Text(time.components(separatedBy: " - ")[1])
                    .vtopFont(size: 12)
.foregroundStyle(.secondary)
            }
            .frame(width: 80, alignment: .leading)

            // Colored bar
            Rectangle()
                .fill(typeColor)
                .frame(width: 4)

            // Course details
            VStack(alignment: .leading, spacing: 4) {
                Text(course)
                    .vtopFont(size: 16, weight: .semibold)
                HStack {
                    Label(room, systemImage: "mappin.circle.fill")
                        .vtopFont(size: 12)
.foregroundStyle(.secondary)

                    Spacer()

                    Text(type)
                        .vtopFont(size: 12, weight: .medium)
.padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(typeColor.opacity(0.2))
                        .foregroundStyle(typeColor)
                        .clipShape(.rect(cornerRadius: 6))
                }
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
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
        SemesterMenuView(
            choices: semesterChoices,
            selectedName: attendanceSemesterDisplayName,
            tint: Color(uiColor: .systemBlue),
            bottomPadding: Self.semesterPickerBottomPadding,
            onSelect: { semester in
            attendanceSemesterId = semester.id
            if attendancePickerPrimed {
                dataManager.refreshAttendance(semesterSubId: semester.id, continueAfterMarks: false)
            }
            }
        )
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
                if attendancePickerPrimed, !attendanceSemesterId.isEmpty {
                    await dataManager.refreshAttendance(for: attendanceSemesterId)
                } else {
                    await dataManager.loadAttendanceSemesterPicklist()
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

// MARK: - Profile Tab
struct ProfileTabView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var syncState: DataManagerSyncState
    @EnvironmentObject var friendsStore: FriendsTimetableStore
    @AppStorage(VTOPPrivacyStorage.maskCGPA) private var maskCGPA = false
    @AppStorage(VTOPPrivacyStorage.maskCredits) private var maskCredits = false
    @State private var confirmSignOut = false
    @State private var confirmClearCache = false

    private func shareApp() {
        VTOPShareSheetPresenter.presentAppShareSheet()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OfflineDataBanner(showSyncMetadata: false)
                List {
                // Student Info Section
                if let profile = dataManager.studentProfile {
                    Section("Student Information") {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(profile.name)
                                    .vtopFont(size: 18, weight: .bold)
                                if let semester = profile.semester {
                                    Text(semester)
                                        .vtopFont(size: 14, weight: .medium)
.foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)

                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CGPA")
                                    .vtopFont(size: 13, weight: .medium)
.foregroundStyle(.secondary)
                                Text(maskCGPA ? "••••" : String(format: "%.2f", profile.cgpa))
                                    .vtopFont(size: 16, weight: .semibold)
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
                                    .vtopFont(size: 13, weight: .medium)
.foregroundStyle(.secondary)
                                Text(maskCredits ? "•••" : "\(Int(profile.totalCredits))")
                                    .vtopFont(size: 16, weight: .semibold)
}
                            Spacer()
                            PrivacyMaskToggleButton(
                                isMasked: $maskCredits,
                                accessibilityShow: "Show credits",
                                accessibilityHide: "Mask credits"
                            )
                        }
                        .padding(.vertical, 2)

                        Button(action: shareApp) {
                            HStack {
                                Label("Share App", systemImage: "square.and.arrow.up")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)

                        if let required = profile.totalCreditsRequired {
                            HStack {
                                Text("Total credits required")
                                    .vtopFont(size: 13, weight: .medium)
.foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.0f", required))
                                    .vtopFont(size: 15, weight: .semibold)
}
                            .padding(.vertical, 2)
                        }

                        if let nonGraded = profile.nonGradedCoreRequirement {
                            HStack {
                                Text("Non-graded core requirement")
                                    .vtopFont(size: 13, weight: .medium)
.foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.1f", nonGraded))
                                    .vtopFont(size: 15, weight: .semibold)
}
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Academic Information") {
                    NavigationLink(destination: ProfileHubView(hub: .classes)) {
                        VTOPSettingsRow(icon: "books.vertical.fill", color: .blue, title: "Classes", detail: "Courses and timetable")
                    }

                    NavigationLink(destination: ProfileHubView(hub: .performance)) {
                        VTOPSettingsRow(icon: "chart.bar.xaxis", color: .purple, title: "Performance", detail: "Marks, grades, and GPA")
                    }

                    NavigationLink(destination: ExamScheduleView().environmentObject(dataManager)) {
                        VTOPSettingsRow(icon: "calendar.and.person", color: .red, title: "Exam Schedule", detail: "See upcoming examinations")
                    }

                    NavigationLink(destination: EventHubView().environmentObject(dataManager)) {
                        VTOPSettingsRow(icon: "calendar.badge.clock", color: .cyan, title: "Event hub", detail: "Campus events and announcements")
                    }

                    NavigationLink(destination: ProfileHubView(hub: .learning)) {
                        VTOPSettingsRow(icon: "brain.head.profile", color: .pink, title: "Learning tools", detail: "Notes, to-dos, and NPTEL quizzes")
                    }
                }

                Section("Campus & community") {
                    NavigationLink(destination: ProfileHubView(hub: .studentAccount)) {
                        VTOPSettingsRow(icon: "person.text.rectangle", color: .indigo, title: "Student account", detail: "Profile, credentials, and receipts")
                    }
                    NavigationLink(destination: ProfileHubView(hub: .campusCommunity)) {
                        VTOPSettingsRow(icon: "person.3.fill", color: .teal, title: "Campus & community", detail: "Staff, resources, and friends")
                    }
                }

                Section("App settings") {
                    NavigationLink(destination: ProfileHubView(hub: .appSettings)) {
                        VTOPSettingsRow(icon: "gearshape.fill", color: .gray, title: "App settings", detail: "Personalization, sync, and cache")
                    }
                }

                Section("About VIT Connect") {
                    NavigationLink(destination: ProfileHubView(hub: .about)) {
                        VTOPSettingsRow(icon: "info.circle.fill", color: .blue, title: "About VIT Connect", detail: "Legal, support, and upcoming features")
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
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
        .environmentObject(dataManager.syncState)
        .environmentObject(FriendsTimetableStore())
        .environmentObject(NotesAndTodosStore())
}
