import SwiftUI
import Foundation

@main
struct ios_vtop_chennaiApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var dataManager = DataManager()

    init() {
        VTOPNotificationScheduler.registerDelegate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authViewModel)
                .environmentObject(dataManager)
                .onAppear {
                    authViewModel.dataManager = dataManager
                    VTOPNotificationScheduler.requestAuthorizationIfNeeded()
                    print("⚠️ DEBUG: App initialized - dataManager connected")
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    /// `false` = light, `true` = dark (Profile → Dark mode toggle).
    @AppStorage("vtop_dark_mode") private var darkModeEnabled = false

    private var preferredColorScheme: ColorScheme? {
        darkModeEnabled ? .dark : .light
    }
    private let debugLogPath = "/Users/msnabiel/Desktop/ios-vtop-chennai/.cursor/debug-a1b485.log"
    private var debugAuthInstanceId: String { String(ObjectIdentifier(authViewModel).hashValue) }
    @State private var sharedTimetableImportNotice: String?

    // #region agent log
    private func emitDebugLog(hypothesisId: String, location: String, message: String, data: [String: Any]) {
        let payload: [String: Any] = [
            "sessionId": "a1b485",
            "runId": "pre-fix",
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let raw = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: raw, encoding: .utf8) else { return }
        let output = line + "\n"
        if let fileHandle = FileHandle(forWritingAtPath: debugLogPath) {
            defer { try? fileHandle.close() }
            do {
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: Data(output.utf8))
            } catch { }
        } else {
            try? output.write(toFile: debugLogPath, atomically: true, encoding: .utf8)
        }
    }
    // #endregion

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                HomeView()
                    .preferredColorScheme(preferredColorScheme)
                    .transition(.opacity)
                    .onAppear {
                        VTOPNotificationScheduler.requestAuthorizationIfNeeded()
                        print("⚠️ DEBUG: ✅✅✅ HomeView APPEARED")
                        // #region agent log
                        emitDebugLog(
                            hypothesisId: "H5",
                            location: "RootView.HomeView.onAppear",
                            message: "HomeView appeared",
                            data: [
                                "isAuthenticated": authViewModel.isAuthenticated,
                                "authInstanceId": debugAuthInstanceId
                            ]
                        )
                        // #endregion
                    }
            } else {
                LoginView()
                    .preferredColorScheme(preferredColorScheme)
                    .transition(.opacity)
                    .onAppear {
                        print("⚠️ DEBUG: LoginView appeared")
                        // #region agent log
                        emitDebugLog(
                            hypothesisId: "H6",
                            location: "RootView.LoginView.onAppear",
                            message: "LoginView appeared in RootView",
                            data: [
                                "isAuthenticated": authViewModel.isAuthenticated,
                                "authInstanceId": debugAuthInstanceId
                            ]
                        )
                        // #endregion
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .onOpenURL { url in
            handleIncomingDeepLink(url)
        }
        .alert(
            "Full sync limit",
            isPresented: Binding(
                get: { dataManager.fullSyncQuotaBlockedMessage != nil },
                set: { if !$0 { dataManager.fullSyncQuotaBlockedMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                dataManager.fullSyncQuotaBlockedMessage = nil
            }
        } message: {
            Text(dataManager.fullSyncQuotaBlockedMessage ?? "")
        }
        .alert(
            "Full sync",
            isPresented: Binding(
                get: { dataManager.fullSyncConfirmSlotsRemaining != nil },
                set: { if !$0 { dataManager.cancelUserFullSyncConfirmation() } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                dataManager.cancelUserFullSyncConfirmation()
            }
            Button("Sync now") {
                dataManager.confirmUserFullSyncAndExecute()
            }
        } message: {
            if let n = dataManager.fullSyncConfirmSlotsRemaining {
                Text("You can run at most 3 full syncs per hour. You have \(n) full sync(s) remaining before you reach that limit. To refresh only one area with less load on VTOP, pull to refresh on that screen.")
            }
        }
        .alert(
            "Timetable imported",
            isPresented: Binding(
                get: { sharedTimetableImportNotice != nil },
                set: { if !$0 { sharedTimetableImportNotice = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                sharedTimetableImportNotice = nil
            }
        } message: {
            Text(sharedTimetableImportNotice ?? "")
        }
        #if DEBUG
        .onChange(of: authViewModel.isAuthenticated) { _, newValue in
            print("⚠️ DEBUG: RootView auth → \(newValue)")
        }
        #endif
    }

    private func handleIncomingDeepLink(_ url: URL) {
        guard let payload = TimetableShareCodec.decodeDeepLink(url) else { return }
        dataManager.importSharedTimetable(payload)
        let title = payload.semesterName?.isEmpty == false ? payload.semesterName! : "Shared timetable"
        sharedTimetableImportNotice = "\(title) imported successfully."
    }
}
