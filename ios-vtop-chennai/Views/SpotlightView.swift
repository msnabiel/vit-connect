import SwiftUI

struct SpotlightView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedCategory: String = "All"

    var categories: [String] {
        var cats = Set(dataManager.spotlights.map { $0.category })
        return ["All"] + cats.sorted()
    }

    var filteredSpotlights: [Spotlight] {
        if selectedCategory == "All" {
            return dataManager.spotlights
        } else {
            return dataManager.spotlights.filter { $0.category == selectedCategory }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if dataManager.spotlights.isEmpty {
                EmptyStateView(
                    icon: "megaphone.fill",
                    message: "No announcements available"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = category
                                }
                            }) {
                                Text(category)
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == category ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                                    )
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(Color(uiColor: .systemBackground))

                // Announcements list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if filteredSpotlights.isEmpty {
                            EmptyStateView(
                                icon: "tray.fill",
                                message: "No announcements in this category"
                            )
                            .padding(.top, 100)
                        } else {
                            ForEach(filteredSpotlights) { spotlight in
                                SpotlightCard(spotlight: spotlight)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
                .refreshable {
                    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                        dataManager.refreshSpotlightsOnly { cont.resume() }
                    }
                }
            }
        }
        .navigationTitle("Announcements")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SpotlightCard: View {
    let spotlight: Spotlight
    @State private var showingWebView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: categoryIcon(spotlight.category))
                        .font(.system(size: 12))

                    Text(spotlight.category)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(categoryColor(spotlight.category))
                )

                Spacer()

                if spotlight.link != nil {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
            }

            // Announcement text
            Text(spotlight.announcement)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            // Action button if link exists
            if let link = spotlight.link {
                Button(action: {
                    if let url = URL(string: link) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Text("View Details")
                            .font(.system(size: 14, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(categoryColor(spotlight.category).opacity(0.3), lineWidth: 1)
        )
    }

    private func categoryIcon(_ category: String) -> String {
        let lowercased = category.lowercased()

        if lowercased.contains("exam") {
            return "doc.text.fill"
        } else if lowercased.contains("event") {
            return "calendar.badge.exclamationmark"
        } else if lowercased.contains("fee") || lowercased.contains("payment") {
            return "creditcard.fill"
        } else if lowercased.contains("holiday") {
            return "calendar.badge.clock"
        } else if lowercased.contains("academic") {
            return "book.fill"
        } else if lowercased.contains("placement") || lowercased.contains("career") {
            return "briefcase.fill"
        } else {
            return "megaphone.fill"
        }
    }

    private func categoryColor(_ category: String) -> Color {
        let lowercased = category.lowercased()

        if lowercased.contains("exam") {
            return .red
        } else if lowercased.contains("event") {
            return .purple
        } else if lowercased.contains("fee") || lowercased.contains("payment") {
            return .orange
        } else if lowercased.contains("holiday") {
            return .green
        } else if lowercased.contains("academic") {
            return .blue
        } else if lowercased.contains("placement") || lowercased.contains("career") {
            return .indigo
        } else {
            return .accentColor
        }
    }
}

#Preview {
    SpotlightView()
        .environmentObject(DataManager())
}
