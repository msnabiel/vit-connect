import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String?
    let message: String

    init(icon: String, title: String? = nil, message: String) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .vtopFont(size: 48)
.foregroundStyle(.secondary)

            if let title = title {
                Text(title)
                    .vtopFont(size: 20, weight: .semibold)
.foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }

            Text(message)
                .vtopFont(size: 15, weight: .medium)
.foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

#Preview {
    EmptyStateView(icon: "doc.text.fill", title: "No Data", message: "No data available")
}
