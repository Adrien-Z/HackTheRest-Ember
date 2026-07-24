import Foundation

/// A science-grounded model of the day's circadian alertness rhythm, anchored to
/// the user's own habitual wake and bed times. Pure and testable — no UI, no
/// HealthKit. It is deliberately a *shape* model (relative alertness 0–1), not a
/// clinical measurement, used to help the user plan their day around their body
/// clock (morning peak, post-lunch dip, evening wake-maintenance zone, wind-down).
///
/// Grounding:
///   • Two-process model of sleep regulation (Borbély 1982): alertness ≈ the
///     interplay of circadian Process C and homeostatic Process S.
///   • Post-lunch dip — a circadian trough in alertness ~7–8 h after wake,
///     independent of eating (Monk 2005).
///   • Evening "wake-maintenance zone" / forbidden zone for sleep ~2–3 h before
///     habitual bed, when the circadian alerting signal peaks (Lavie 1986).
///   • Melatonin onset (DLMO) ~2 h before habitual sleep (wind-down window).
///   • Core-body-temperature minimum ~2 h before habitual wake (deepest sleep).
enum CircadianModel {

    /// One sampled point of the alertness curve.
    struct Sample: Identifiable {
        var id: Int { minuteOfDay }
        let minuteOfDay: Int     // 0..1440
        let alertness: Double    // 0 (deep trough) … 1 (peak)
    }

    enum MarkerKind { case peak, dip, windDown, deepSleep, caffeine }

    struct Marker: Identifiable {
        var id: String { label }
        let minuteOfDay: Int
        let label: String
        let detail: String
        let symbol: String
        let kind: MarkerKind
    }

    /// Alertness (0–1) at a given minute-of-day, anchored to wake/bed. Values are
    /// interpolated across control points scaled to the user's wake window, so
    /// the same recognizable shape adapts to a lark or an owl.
    static func alertness(atMinute t: Int, wakeMin: Int, bedMin: Int) -> Double {
        let ww = wakeWindowMin(wakeMin: wakeMin, bedMin: bedMin)   // awake span
        // Position within the wake window [0,1], or nil if asleep.
        let sinceWake = ((t - wakeMin) % 1440 + 1440) % 1440
        if sinceWake <= ww {
            let f = Double(sinceWake) / Double(ww)
            return interpolate(fraction: f, points: wakeControlPoints)
        }
        // Asleep: descend from bed to the core-temp minimum, then rise toward wake.
        let sinceBed = ((t - bedMin) % 1440 + 1440) % 1440
        let sleepSpan = 1440 - ww
        let g = Double(sinceBed) / Double(max(1, sleepSpan))       // 0 at bed … 1 at wake
        // Trough placed near CBTmin (~2 h before wake → late in the sleep span).
        let troughAt = sleepSpan > 0 ? Double(sleepSpan - 120) / Double(sleepSpan) : 0.8
        let dist = abs(g - troughAt)
        return max(0.03, 0.22 - 0.19 * (1 - min(1, dist / 0.5)))
    }

    /// The full curve sampled every `step` minutes across 24 h.
    static func curve(wakeMin: Int, bedMin: Int, step: Int = 10) -> [Sample] {
        stride(from: 0, through: 1440, by: step).map {
            Sample(minuteOfDay: $0 % 1440, alertness: alertness(atMinute: $0, wakeMin: wakeMin, bedMin: bedMin))
        }
    }

    /// The teaching markers placed on the day.
    static func markers(wakeMin: Int, bedMin: Int) -> [Marker] {
        let ww = wakeWindowMin(wakeMin: wakeMin, bedMin: bedMin)
        func add(_ frac: Double) -> Int { (wakeMin + Int(Double(ww) * frac)) % 1440 }
        var out: [Marker] = [
            Marker(minuteOfDay: add(0.25), label: "Morning peak",
                   detail: "Your sharpest focus of the day — protect it for demanding work.",
                   symbol: "sun.max.fill", kind: .peak),
            Marker(minuteOfDay: add(0.45), label: "Afternoon dip",
                   detail: "A natural alertness trough ~7–8 h after waking. Ideal for a short walk or a 10–20 min nap — not heavy caffeine.",
                   symbol: "arrow.down.right.circle.fill", kind: .dip),
            Marker(minuteOfDay: add(0.80), label: "Evening peak",
                   detail: "A wake-maintenance zone: your body resists sleep now. Feeling wired is normal — don't fight for an early bed here.",
                   symbol: "bolt.fill", kind: .peak),
            Marker(minuteOfDay: (bedMin - 120 + 1440) % 1440, label: "Wind-down begins",
                   detail: "Melatonin starts rising ~2 h before bed. Dim lights, warm up, and step away from screens.",
                   symbol: "moon.haze.fill", kind: .windDown),
            Marker(minuteOfDay: (wakeMin - 120 + 1440) % 1440, label: "Deepest sleep",
                   detail: "Core body temperature bottoms out ~2 h before wake — the hardest time to rouse.",
                   symbol: "thermometer.low", kind: .deepSleep),
        ]
        // Caffeine cutoff ~8 h before bed (≈1.5 half-lives) — a concrete lever.
        out.append(Marker(minuteOfDay: (bedMin - 480 + 1440) % 1440, label: "Last coffee",
                          detail: "Caffeine has a ~5–6 h half-life. After this, a cup can still be measurably in your system at bedtime.",
                          symbol: "cup.and.saucer.fill", kind: .caffeine))
        return out.sorted { $0.minuteOfDay < $1.minuteOfDay }
    }

    // MARK: - Internals

    /// Awake span in minutes (bed − wake, wrapped). Falls back to 16 h if degenerate.
    private static func wakeWindowMin(wakeMin: Int, bedMin: Int) -> Int {
        let w = ((bedMin - wakeMin) % 1440 + 1440) % 1440
        return w == 0 ? 960 : w
    }

    /// Control points (fraction of wake window → alertness) giving the classic
    /// bimodal curve: groggy rise → morning peak → afternoon dip → evening peak →
    /// steep wind-down.
    private static let wakeControlPoints: [(Double, Double)] = [
        (0.00, 0.35), (0.12, 0.70), (0.25, 0.88), (0.38, 0.74),
        (0.46, 0.52), (0.60, 0.74), (0.80, 0.84), (0.90, 0.58), (1.00, 0.28),
    ]

    private static func interpolate(fraction f: Double, points: [(Double, Double)]) -> Double {
        let x = min(max(f, 0), 1)
        for i in 1..<points.count where x <= points[i].0 {
            let (x0, y0) = points[i - 1], (x1, y1) = points[i]
            let t = (x - x0) / max(0.0001, x1 - x0)
            // Smoothstep for a soft, organic curve.
            let s = t * t * (3 - 2 * t)
            return y0 + (y1 - y0) * s
        }
        return points.last?.1 ?? 0.5
    }
}
