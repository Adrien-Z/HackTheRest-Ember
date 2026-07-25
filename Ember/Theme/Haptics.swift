import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Small, centralized haptic vocabulary so feedback feels consistent app-wide.
/// No-ops cleanly on platforms without UIKit haptics (e.g. previews, macOS).
enum Haptics {
    #if canImport(UIKit)
    private static let selection = UISelectionFeedbackGenerator()
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private static let notify = UINotificationFeedbackGenerator()
    #endif

    /// Discrete "value changed" tick — scrubbing a chart, moving between points.
    static func tick() {
        #if canImport(UIKit)
        selection.selectionChanged()
        selection.prepare()
        #endif
    }

    /// A soft tap — a token arriving while the coach streams.
    static func stream() {
        #if canImport(UIKit)
        impactSoft.impactOccurred(intensity: 0.4)
        #endif
    }

    /// A light tap — a primary control, a chart finishing its draw-in.
    static func light() {
        #if canImport(UIKit)
        impactLight.impactOccurred()
        impactLight.prepare()
        #endif
    }

    /// A firmer tap — phase changes, mode changes, larger state transitions.
    static func medium() {
        #if canImport(UIKit)
        impactMedium.impactOccurred()
        impactMedium.prepare()
        #endif
    }

    /// A success flourish — a plan locked in, a goal met.
    static func success() {
        #if canImport(UIKit)
        notify.notificationOccurred(.success)
        #endif
    }
}
