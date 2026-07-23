import SwiftUI

/// EMBER visual system — a calm, dark, "warm ember" palette suited to a rest app.
enum Theme {
    // Warm ember accent gradient
    static let ember      = Color(red: 0.94, green: 0.42, blue: 0.20)   // #F06B33
    static let emberDeep  = Color(red: 0.76, green: 0.27, blue: 0.09)   // #C24417
    static let cool       = Color(red: 0.36, green: 0.47, blue: 0.75)   // thermal "cool" band
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
