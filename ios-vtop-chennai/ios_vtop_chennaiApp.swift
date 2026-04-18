import SwiftUI
import Foundation

@main
struct ios_vtop_chennaiApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var dataManager = DataManager()

    init() {
        // This won't work in init - we need to do it differently
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authViewModel)
                .environmentObject(dataManager)
                .onAppear {
                    // Connect them when the app appears
                    authViewModel.dataManager = dataManager
                    print("⚠️ DEBUG: App initialized - dataManager connected")
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager
    private let debugLogPath = "/Users/msnabiel/Desktop/ios-vtop-chennai/.cursor/debug-a1b485.log"
    private var debugAuthInstanceId: String { String(ObjectIdentifier(authViewModel).hashValue) }

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
        let _ = print("⚠️ DEBUG: RootView body evaluated - isAuthenticated = \(authViewModel.isAuthenticated)")
        // #region agent log
        let _ = emitDebugLog(
            hypothesisId: "H5",
            location: "RootView.body",
            message: "RootView body evaluated",
            data: ["isAuthenticated": authViewModel.isAuthenticated]
        )
        // #endregion

        return Group {
            if authViewModel.isAuthenticated {
                HomeView()
                    .transition(.opacity)
                    .onAppear {
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
        .onChange(of: authViewModel.isAuthenticated) { newValue in
            print("⚠️ DEBUG: 🔔 RootView onChange fired - new value = \(newValue)")
            // #region agent log
            emitDebugLog(
                hypothesisId: "H5",
                location: "RootView.onChange.isAuthenticated",
                message: "RootView observed auth state change",
                data: [
                    "newValue": newValue,
                    "authInstanceId": debugAuthInstanceId
                ]
            )
            // #endregion
        }
    }
}
