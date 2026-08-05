import SwiftUI

enum VTOPProfileHub: String, Identifiable {
    case classes = "Classes"
    case performance = "Performance"
    case studentAccount = "Student account"
    case campusCommunity = "Campus & community"
    case learning = "Learning tools"
    case appSettings = "App settings"
    case about = "About VIT Connect"

    var id: Self { self }
}

struct ProfileHubView: View {
    let hub: VTOPProfileHub
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var syncState: DataManagerSyncState
    @EnvironmentObject private var friendsStore: FriendsTimetableStore

    var body: some View {
        List {
            switch hub {
            case .classes:
                Section("Classes") {
                    NavigationLink(destination: CoursesDetailView().environmentObject(dataManager)) {
                        Label("Courses", systemImage: "book.fill")
                    }
                    NavigationLink(destination: TimetableView().environmentObject(authViewModel).environmentObject(dataManager)) {
                        Label("Timetable", systemImage: "calendar")
                    }
                }
            case .performance:
                Section("Performance") {
                    NavigationLink(destination: MarksBySemesterView().environmentObject(dataManager)) {
                        Label("Marks", systemImage: "doc.text.magnifyingglass")
                    }
                    NavigationLink(destination: GradeHistoryView().environmentObject(dataManager)) {
                        Label("Grade history", systemImage: "chart.bar.doc.horizontal")
                    }
                    NavigationLink(destination: GPACalculatorView().environmentObject(dataManager)) {
                        Label("GPA Calculator", systemImage: "function")
                    }
                }
            case .studentAccount:
                Section("Student account") {
                    NavigationLink(destination: FullStudentProfileView().environmentObject(dataManager)) {
                        Label("Full profile", systemImage: "person.text.rectangle")
                    }
                    NavigationLink(destination: PortalCredentialsView().environmentObject(dataManager)) {
                        Label("Portal credentials & rank", systemImage: "key.fill")
                    }
                    NavigationLink(destination: ReceiptsView().environmentObject(dataManager)) {
                        Label("Payment Receipts", systemImage: "doc.text.fill")
                    }
                }
            case .campusCommunity:
                Section("Campus & community") {
                    NavigationLink(destination: StaffInformationView().environmentObject(dataManager)) {
                        Label("Staff Information", systemImage: "person.2.fill")
                    }
                    Link(destination: URL(string: "https://drive.google.com/drive/folders/1Z4tBts_Y55n4m8yRSyV7WzKocVHpi9yC")!) {
                        Label("Study Materials", systemImage: "books.vertical.fill")
                    }
                    NavigationLink(destination: ImportFriendsTimetableView().environmentObject(friendsStore)) {
                        Label("Import timetable", systemImage: "square.and.arrow.down")
                    }
                    NavigationLink(destination: FriendsTimetableListView().environmentObject(friendsStore)) {
                        Label("Friends timetable", systemImage: "person.2.square.stack")
                    }
                    NavigationLink(destination: CompareTimetablesView().environmentObject(dataManager).environmentObject(friendsStore)) {
                        Label("Compare timetables", systemImage: "rectangle.2.swap")
                    }
                }
                if let openRoleURL = URL(string: "itms-apps://apps.apple.com/us/app/openrole-ai-job-search/id6775263884") {
                    Section("Career") {
                        Link(destination: openRoleURL) {
                            Label("OpenRole - AI Job Search", systemImage: "briefcase.fill")
                        }
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Career") {
                        Text("DEBUG: Invalid URL")
                            .foregroundStyle(.red)
                    }
                }
            case .learning:
                Section("Learning tools") {
                    NavigationLink(destination: NotesAndTodosHubView()) {
                        Label("Notes & To-Do", systemImage: "pencil.and.list.clipboard")
                    }
                    NavigationLink(destination: NPTELQuizView()) {
                        Label("NPTEL Quiz", systemImage: "brain.head.profile")
                    }
                }
            case .appSettings:
                Section("App settings") {
                    NavigationLink(destination: PersonalizationView()) {
                        Label("Personalization", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink(destination: CacheManagementView()) {
                        Label("Cache management", systemImage: "externaldrive.fill")
                    }
                    Button {
                        authViewModel.triggerSync()
                    } label: {
                        Label(syncState.isLoading ? "Syncing…" : "Full Sync Data", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(syncState.isLoading)
                }
            case .about:
                Section("About VIT Connect") {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy policy", systemImage: "hand.raised.fill")
                    }
                    NavigationLink(destination: TermsAndConditionsView()) {
                        Label("Terms and conditions", systemImage: "doc.plaintext")
                    }
                    Link(destination: URL(string: "https://docs.google.com/forms/d/e/1FAIpQLScN1VjOZJ0MqUrADnkt_WkYIclAT3KEpT0XSRa_jptUBAIfSQ/viewform")!) {
                        Label("Bugs & suggestions", systemImage: "ladybug.fill")
                    }
                    Text("VIT Bhopal and VIT Vellore — support coming soon.")
                        .font(.subheadline)
                    Text("Moodle integration — coming soon.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(hub.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ProfileHubView(hub: .performance)
            .environmentObject(AuthenticationViewModel())
            .environmentObject(DataManager())
            .environmentObject(DataManagerSyncState())
            .environmentObject(FriendsTimetableStore())
    }
}
