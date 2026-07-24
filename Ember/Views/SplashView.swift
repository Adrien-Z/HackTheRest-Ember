import SwiftUI

/// Cold-launch splash: the screen itself is the Blue Box. A full-screen blue
/// cover — four carton flaps (top, bottom, then the sides) — unfolds outward
/// starting from the top, while the app underneath zooms up to full size.
/// Skips the theatrics when Reduce Motion is on.
struct SplashView: View {
    /// Fired the moment the flaps start opening — the app begins its zoom-in.
    var onReveal: () -> Void = {}
    /// Fired when the animation is done and the overlay can be removed.
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var topOpen = false
    @State private var bottomOpen = false
    @State private var sidesOpen = false
    /// Starts hidden: frame one is a flat blue that exactly matches the static
    /// launch screen (UILaunchScreen → LaunchBackground), so the handoff from
    /// system launch to this view is invisible. The wordmark is the first beat.
    @State private var wordmarkVisible = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Side flaps, tucked beneath top/bottom like a real carton.
                flap
                    .frame(width: w / 2, height: h)
                    .rotation3DEffect(.degrees(sidesOpen ? -120 : 0), axis: (x: 0, y: 1, z: 0),
                                      anchor: .leading, perspective: 0.25)
                    .opacity(sidesOpen ? 0 : 1)
                    .position(x: w / 4, y: h / 2)
                flap
                    .frame(width: w / 2, height: h)
                    .rotation3DEffect(.degrees(sidesOpen ? 120 : 0), axis: (x: 0, y: 1, z: 0),
                                      anchor: .trailing, perspective: 0.25)
                    .opacity(sidesOpen ? 0 : 1)
                    .position(x: w * 3 / 4, y: h / 2)
                // Bottom flap folds down and away.
                flap
                    .frame(width: w, height: h / 2)
                    .rotation3DEffect(.degrees(bottomOpen ? 120 : 0), axis: (x: 1, y: 0, z: 0),
                                      anchor: .bottom, perspective: 0.25)
                    .opacity(bottomOpen ? 0 : 1)
                    .position(x: w / 2, y: h * 3 / 4)
                // Top flap — the first to peel open.
                flap
                    .frame(width: w, height: h / 2)
                    .rotation3DEffect(.degrees(topOpen ? -120 : 0), axis: (x: 1, y: 0, z: 0),
                                      anchor: .top, perspective: 0.25)
                    .opacity(topOpen ? 0 : 1)
                    .position(x: w / 2, y: h / 4)
                // Wordmark riding on the closed box.
                VStack(spacing: 6) {
                    Text("EMBER")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .kerning(8)
                    Text("BY BLUE BOX")
                        .font(.caption2.weight(.semibold)).kerning(4)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .foregroundStyle(.white)
                .opacity(wordmarkVisible ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .task { await run() }
    }

    // Flat brand blue, no seams or gradient: identical to the launch screen
    // color so the closed box is indistinguishable from the system launch frame.
    private var flap: some View {
        Rectangle().fill(Theme.ember)
    }

    private func run() async {
        if reduceMotion {
            wordmarkVisible = true
            onReveal()
            try? await Task.sleep(nanoseconds: 600_000_000)
            onFinished()
            return
        }
        withAnimation(.easeIn(duration: 0.3)) { wordmarkVisible = true }
        try? await Task.sleep(nanoseconds: 850_000_000)
        withAnimation(.easeOut(duration: 0.2)) { wordmarkVisible = false }
        try? await Task.sleep(nanoseconds: 180_000_000)
        onReveal()
        withAnimation(.easeIn(duration: 0.5)) { topOpen = true }
        try? await Task.sleep(nanoseconds: 160_000_000)
        withAnimation(.easeIn(duration: 0.5)) { bottomOpen = true }
        try? await Task.sleep(nanoseconds: 160_000_000)
        withAnimation(.easeIn(duration: 0.45)) { sidesOpen = true }
        try? await Task.sleep(nanoseconds: 650_000_000)
        onFinished()
    }
}
