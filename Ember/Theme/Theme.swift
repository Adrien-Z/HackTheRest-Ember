import SwiftUI

/// EMBER visual system — Blue Box's brand blue on a calm, dark night palette.
enum Theme {
    // Blue Box brand accent. `ember` keeps its name (it's the app-wide accent
    // referenced everywhere) but now carries the exact logo blue.
    static let ember      = Color(red: 0.000, green: 0.278, blue: 0.729)   // #0047BA Blue Box logo blue
    static let emberDeep  = Color(red: 0.086, green: 0.173, blue: 0.376)   // #162C60 Blue Box deep navy
    static let cool       = Color(red: 0.66, green: 0.75, blue: 0.88)      // periwinkle (CBT-I), from BB palette
    static let mint       = Color(red: 0.30, green: 0.78, blue: 0.60)   // "hit"/success
    static let amber      = Color(red: 0.98, green: 0.75, blue: 0.29)   // partial
    static let bg         = Color(red: 0.06, green: 0.07, blue: 0.11)   // near-black navy
    static let card       = Color(red: 0.11, green: 0.12, blue: 0.17)

    static var emberGradient: LinearGradient {
        LinearGradient(colors: [ember, emberDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var nightGradient: LinearGradient {
        LinearGradient(colors: [Color(red:0.09,green:0.10,blue:0.18), bg],
                       startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    /// Standard EMBER card container (material + rounded corners).
    func emberCard(_ padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}
