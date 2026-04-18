import SwiftUI

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.95, blue: 1.0),
                    Color(red: 0.95, green: 0.98, blue: 1.0)
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 5)
                    .repeatForever(autoreverses: true)
                ) {
                    animateGradient.toggle()
                }
            }

            // Overlay mesh gradients
            GeometryReader { geometry in
                ZStack {
                    // Blue blob
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(0.15),
                                    Color.blue.opacity(0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(x: animateGradient ? -100 : 100, y: animateGradient ? -50 : 50)
                        .blur(radius: 60)

                    // Purple blob
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.15),
                                    Color.purple.opacity(0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 350, height: 350)
                        .offset(x: animateGradient ? 100 : -100, y: geometry.size.height - (animateGradient ? 200 : 300))
                        .blur(radius: 50)

                    // Pink blob
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.pink.opacity(0.12),
                                    Color.pink.opacity(0.04),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 300, height: 300)
                        .offset(x: geometry.size.width - (animateGradient ? 150 : 250), y: geometry.size.height / 2)
                        .blur(radius: 55)

                    // Green blob
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.10),
                                    Color.green.opacity(0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 280, height: 280)
                        .offset(x: animateGradient ? geometry.size.width - 100 : 50, y: animateGradient ? 100 : 200)
                        .blur(radius: 45)
                }
            }
        }
    }
}

#Preview {
    AnimatedGradientBackground()
}
