import SwiftUI

struct HomeSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SkeletonBlock(height: 150, radius: 20)
            HStack(spacing: 12) {
                SkeletonBlock(height: 110)
                SkeletonBlock(height: 110)
            }
            SkeletonBlock(height: 170)
        }
        .padding(.horizontal, 16)
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading academic dashboard")
    }
}

private struct SkeletonBlock: View {
    let height: CGFloat
    var radius: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill))
            .frame(maxWidth: .infinity, minHeight: height)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Capsule().fill(Color(uiColor: .quaternarySystemFill)).frame(width: 120, height: 12)
                    Capsule().fill(Color(uiColor: .quaternarySystemFill)).frame(width: 190, height: 12)
                }
                .padding(16)
            }
    }
}
