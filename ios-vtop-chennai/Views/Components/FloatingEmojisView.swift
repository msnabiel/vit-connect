import SwiftUI

struct FloatingEmojisView: View {
    let emojis = ["📚", "✏️", "📖", "🎓", "💯", "⭐️", "✨", "🌟", "📝", "🎯"]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<15, id: \.self) { index in
                    FloatingEmoji(
                        emoji: emojis[index % emojis.count],
                        geometry: geometry,
                        index: index
                    )
                }
            }
        }
    }
}

struct FloatingEmoji: View {
    let emoji: String
    let geometry: GeometryProxy
    let index: Int

    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 0.3

    var body: some View {
        Text(emoji)
            .font(.system(size: CGFloat.random(in: 20...50)))
            .opacity(opacity)
            .offset(x: xOffset, y: yOffset)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                // Random starting position
                xOffset = CGFloat.random(in: -geometry.size.width/2...geometry.size.width/2)
                yOffset = geometry.size.height + 100

                // Animate floating up
                withAnimation(
                    .linear(duration: Double.random(in: 15...25))
                    .repeatForever(autoreverses: false)
                    .delay(Double(index) * 0.5)
                ) {
                    yOffset = -200
                }

                // Animate horizontal drift
                withAnimation(
                    .easeInOut(duration: Double.random(in: 3...6))
                    .repeatForever(autoreverses: true)
                    .delay(Double.random(in: 0...2))
                ) {
                    xOffset += CGFloat.random(in: -50...50)
                }

                // Animate rotation
                withAnimation(
                    .linear(duration: Double.random(in: 10...20))
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }

                // Animate opacity
                withAnimation(
                    .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = Double.random(in: 0.2...0.5)
                }
            }
    }
}

#Preview {
    FloatingEmojisView()
}
