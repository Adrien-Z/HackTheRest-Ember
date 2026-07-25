import SwiftUI

struct SkinRevealPreview: View {
    let decoration: BoxDecoration?
    let size: CGSize
    let revealToken: Int

    @State private var scale: CGFloat = 1
    @State private var rotation: Double = 0
    @State private var showSparkles = false

    var body: some View {
        ZStack {
            BoxSkinImageView(decoration: decoration, size: size)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))

            SkinRevealSparkle(isVisible: showSparkles)
        }
        .onChange(of: revealToken) {
            playRevealAnimation()
        }
    }

    private func playRevealAnimation() {
        scale = 0.9
        rotation = -2
        showSparkles = false

        withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
            scale = 1.08
            rotation = 2
            showSparkles = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                scale = 1
                rotation = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            withAnimation(.easeOut(duration: 0.22)) {
                showSparkles = false
            }
        }
    }
}

struct SkinRevealSparkle: View {
    let isVisible: Bool

    private let sparkles: [Sparkle] = [
        Sparkle(symbol: "sparkle", x: -74, y: -48, size: 13, color: Theme.mint),
        Sparkle(symbol: "star.fill", x: 82, y: -32, size: 8, color: Theme.amber),
        Sparkle(symbol: "sparkle", x: 66, y: 42, size: 11, color: Theme.boxBlue),
        Sparkle(symbol: "star.fill", x: -54, y: 38, size: 7, color: Theme.cool),
        Sparkle(symbol: "sparkle", x: 10, y: -76, size: 9, color: Theme.mint)
    ]

    var body: some View {
        ZStack {
            ForEach(sparkles) { sparkle in
                Image(systemName: sparkle.symbol)
                    .font(.system(size: sparkle.size, weight: .semibold))
                    .foregroundStyle(sparkle.color.opacity(0.88))
                    .shadow(color: sparkle.color.opacity(0.35), radius: 6)
                    .scaleEffect(isVisible ? 1 : 0.55)
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: sparkle.x, y: sparkle.y)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.22), value: isVisible)
    }
}

private struct Sparkle: Identifiable {
    let id = UUID()
    let symbol: String
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let color: Color
}

struct SkinRevealSparkle_Previews: PreviewProvider {
    static var previews: some View {
        SkinRevealSparkle(isVisible: true)
            .frame(width: 220, height: 220)
            .background(NightBackground())
            .preferredColorScheme(.dark)
    }
}
