import SwiftUI
import Foundation
import SwiftData

@main
struct ios_vtop_chennaiApp: App {
    private let swiftDataStore = VTOPSwiftDataStore.shared
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var dataManager = DataManager()
    @StateObject private var friendsStore = FriendsTimetableStore()
    @StateObject private var notesAndTodosStore = NotesAndTodosStore()

    init() {
        VTOPNotificationScheduler.registerDelegate()
        swiftDataStore.importLegacySemesterCachesIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(swiftDataStore.container)
                .environmentObject(authViewModel)
                .environmentObject(dataManager)
                .environmentObject(dataManager.syncState)
                .environmentObject(friendsStore)
                .environmentObject(notesAndTodosStore)
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
    @EnvironmentObject var syncState: DataManagerSyncState
    @AppStorage(VTOPPersonalizationPreferences.appearanceKey) private var appearanceRaw = VTOPPersonalizationPreferences.Appearance.system.rawValue
    @AppStorage(VTOPPersonalizationPreferences.accentKey) private var accentRaw = VTOPPersonalizationPreferences.Accent.blue.rawValue
    @AppStorage(VTOPPersonalizationPreferences.appLockEnabledKey) private var appLockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = false
    @State private var isAuthenticating = false

    private var preferredColorScheme: ColorScheme? {
        VTOPPersonalizationPreferences.Appearance(rawValue: appearanceRaw)?.colorScheme
    }
    private var debugAuthInstanceId: String { String(ObjectIdentifier(authViewModel).hashValue) }

    // #region agent log
    private func emitDebugLog(hypothesisId: String, location: String, message: String, data: [String: Any]) {
        #if !DEBUG
        return
        #else
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
        let logURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("vtop-debug.log")
        if let fileHandle = FileHandle(forWritingAtPath: logURL.path) {
            defer { try? fileHandle.close() }
            do {
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: Data(output.utf8))
            } catch { }
        } else {
            try? output.write(to: logURL, atomically: true, encoding: .utf8)
        }
        #endif
    }
    // #endregion

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                HomeView()
                    .preferredColorScheme(preferredColorScheme)
                    .tint(VTOPPersonalizationPreferences.Accent(rawValue: accentRaw)?.color ?? .blue)
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
                    .tint(VTOPPersonalizationPreferences.Accent(rawValue: accentRaw)?.color ?? .blue)
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
        .alert(
            "Full sync limit",
            isPresented: Binding(
                get: { syncState.fullSyncQuotaBlockedMessage != nil },
                set: { if !$0 { syncState.fullSyncQuotaBlockedMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                syncState.fullSyncQuotaBlockedMessage = nil
            }
        } message: {
            Text(syncState.fullSyncQuotaBlockedMessage ?? "")
        }
        .alert(
            "Full sync",
            isPresented: Binding(
                get: { syncState.fullSyncConfirmSlotsRemaining != nil },
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
            if let n = syncState.fullSyncConfirmSlotsRemaining {
                Text("You can run at most 3 full syncs per hour. You have \(n) full sync(s) remaining before you reach that limit. To refresh only one area with less load on VTOP, pull to refresh on that screen.")
            }
        }
        #if DEBUG
        .onChange(of: authViewModel.isAuthenticated) { _, newValue in
            print("⚠️ DEBUG: RootView auth → \(newValue)")
        }
        #endif
        .overlay {
            if isLocked {
                AppLockView(isAuthenticating: isAuthenticating, unlock: authenticate)
            }
        }
        .onAppear {
            if appLockEnabled && authViewModel.isAuthenticated { lockAndAuthenticate() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard appLockEnabled, authViewModel.isAuthenticated else { return }
            if phase == .background { isLocked = true }
            if phase == .active, isLocked { authenticate() }
        }
        .onChange(of: appLockEnabled) { _, enabled in
            if !enabled { isLocked = false }
            else if authViewModel.isAuthenticated { lockAndAuthenticate() }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, authenticated in
            if authenticated && appLockEnabled { lockAndAuthenticate() }
            if !authenticated { isLocked = false }
        }
    }

    private func lockAndAuthenticate() {
        isLocked = true
        authenticate()
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task { @MainActor in
            let success = await VTOPBiometricLock.authenticate()
            isAuthenticating = false
            if success { isLocked = false }
        }
    }

    private struct AppLockView: View {
        let isAuthenticating: Bool
        let unlock: () -> Void

        var body: some View {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                VStack(spacing: 18) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("VIT Connect is locked")
                        .font(.title2.weight(.bold))
                    Text("Authenticate to view your academic data.")
                        .foregroundStyle(.secondary)
                    Button(isAuthenticating ? "Waiting…" : "Unlock", systemImage: "faceid", action: unlock)
                        .buttonStyle(.borderedProminent)
                        .disabled(isAuthenticating)
                }
                .padding(24)
            }
        }
    }

}
