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
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            if let title = title {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

#Preview {
    EmptyStateView(icon: "doc.text.fill", title: "No Data", message: "No data available")
}
