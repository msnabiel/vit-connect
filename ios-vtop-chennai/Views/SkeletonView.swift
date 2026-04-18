import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 400 : -400)
            )
            .clipped()
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                SkeletonView()
                    .frame(width: 120, height: 16)

                Spacer()

                SkeletonView()
                    .frame(width: 60, height: 24)
            }

            Divider()

            // Content grid
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView()
                        .frame(width: 80, height: 12)
                    SkeletonView()
                        .frame(width: 100, height: 14)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    SkeletonView()
                        .frame(width: 60, height: 12)
                    SkeletonView()
                        .frame(width: 80, height: 14)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

struct SkeletonListRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView()
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView()
                    .frame(width: 100, height: 12)
                SkeletonView()
                    .frame(width: 150, height: 14)
            }

            Spacer()

            SkeletonView()
                .frame(width: 60, height: 14)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        SkeletonCard()
        SkeletonCard()
        SkeletonListRow()
        SkeletonListRow()
    }
    .padding()
}
