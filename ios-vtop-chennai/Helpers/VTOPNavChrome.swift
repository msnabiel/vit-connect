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
                        .foregroundStyle(Color.accentColor)
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
}

// MARK: - Full sync (same as Profile “Sync Data”)

struct MainSyncToolbarButton: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        Button {
            authViewModel.triggerSync()
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .rotationEffect(.degrees(dataManager.isLoading ? 360 : 0))
                .animation(
                    dataManager.isLoading
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: dataManager.isLoading
                )
        }
        .disabled(dataManager.isLoading)
        .accessibilityLabel("Sync data")
    }
}
