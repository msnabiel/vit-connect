import SwiftUI

enum VTOPNavChrome {
    /// Shared leading symbol for academic / VTOP screens (not used on profile root).
    static let leadingSystemImage = "building.columns.fill"
}

extension View {
    func vtopNavLeadingIcon() -> some View {
        toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Image(systemName: VTOPNavChrome.leadingSystemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
        }
    }
}
