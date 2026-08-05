import SwiftUI

struct TodayCard: View {
    let greeting: String
    let name: String
    let semester: String?
    let hour: Int

    private var accentColors: [Color] {
        switch hour {
        case 5..<12: [.indigo, .blue]
        case 12..<17: [.teal, .blue]
        default: [.blue, .purple]
        }
    }

    private var timeLabel: String {
        switch hour {
        case 5..<12: "MORNING OVERVIEW"
        case 12..<17: "AFTERNOON OVERVIEW"
        default: "EVENING OVERVIEW"
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: accentColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 150, height: 150)
                .offset(x: 58, y: -64)

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 110, height: 110)
                .offset(x: -46, y: 88)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: hour < 12 ? "sunrise.fill" : hour < 17 ? "sun.max.fill" : "moon.stars.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.18), in: .circle)

                    Text(timeLabel)
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.82))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.84))

                    Text(name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }

                HStack(spacing: 8) {
                    Label(semester ?? "Academic overview", systemImage: "graduationcap.fill")
                    Text("•")
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(.white.opacity(0.16), in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .frame(maxWidth: .infinity, minHeight: 172, alignment: .leading)
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .shadow(color: accentColors.last?.opacity(0.25) ?? .clear, radius: 14, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting), \(name). \(semester ?? "Your academic overview")")
    }
}
