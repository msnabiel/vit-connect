import SwiftUI

// MARK: - Jump to Home tab (main shell only)

private struct SelectHomeTabKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// When set (main `TabView`), leading brand icon switches to the Home tab.
    var selectHomeTab: (() -> Void)? {
        get { self[SelectHomeTabKey.self] }
        set { self[SelectHomeTabKey.self] = newValue }
    }
}

// MARK: - Leading icon → Home

enum VTOPNavChrome {
    static let leadingSystemImage = "building.columns.fill"
}

private struct VTOPNavLeadingIconModifier: ViewModifier {
    @Environment(\.selectHomeTab) private var selectHomeTab

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    selectHomeTab?()
                } label: {
                    Image(systemName: VTOPNavChrome.leadingSystemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .disabled(selectHomeTab == nil)
                .accessibilityLabel("Home")
            }
        }
    }
}

extension View {
    /// Leading control: returns to the Home tab when `selectHomeTab` is provided (main shell).
    func vtopNavLeadingIcon() -> some View {
        modifier(VTOPNavLeadingIconModifier())
    }

    /// Solid navigation bar so top-of-screen views (e.g. offline banner) never show through a translucent bar.
    func vtopOpaqueNavigationBar() -> some View {
        self
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Sync arrow (smooth spin while `DataManager.isLoading`)

/// Continuous rotation for the duration of sync / full fetch, including session extraction and failures.
struct VTOPSmoothSyncArrow: View {
    var isRunning: Bool
    var font: Font = .body.weight(.medium)
    var foreground: Color = .primary

    private static let secondsPerTurn: Double = 0.85

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isRunning)) { context in
            let degrees: Double = {
                guard isRunning else { return 0 }
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = t.truncatingRemainder(dividingBy: Self.secondsPerTurn) / Self.secondsPerTurn
                return phase * 360.0
            }()
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(font)
                .foregroundStyle(foreground)
                .rotationEffect(.degrees(degrees))
        }
    }
}

// MARK: - Full sync (same as Profile “Sync Data”)

struct MainSyncToolbarButton: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        Button {
            authViewModel.triggerSync()
        } label: {
            VTOPSmoothSyncArrow(isRunning: dataManager.isLoading, foreground: .primary)
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .disabled(dataManager.isLoading)
        .accessibilityLabel("Sync data")
    }
}
