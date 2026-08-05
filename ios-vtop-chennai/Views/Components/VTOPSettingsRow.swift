import SwiftUI

/// Native iOS settings row inspired by the FlowKit settings surface.
struct VTOPSettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)
        }
    }
}
