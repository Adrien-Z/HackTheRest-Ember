import Foundation

/// Pure, HealthKit-free sleep-metric derivation. `HealthManager` maps raw
/// `HKCategorySample`s into `[SleepInterval]`; everything below is testable
/// without a device.
///
/// Metric definitions follow the Consensus Sleep Diary (Carney et al., SLEEP
/// 2012) and standard AASM/PSG conventions:
///   • TIB  — time in bed: span of the in-bed interval(s).
///   • SOL  — sleep-onset latency: first-asleep − lights-out (time to fall asleep).
///   • TST  — total sleep time: sum of all asleep-stage durations.
///   • WASO — wake after sleep onset: awake time between sleep onset and final wake.
///   • SE   — sleep efficiency: TST / TIB × 100 (widely published AASM denominator).
/// Apple's sleep model (HKCategoryValueSleepAnalysis) records an in-bed sample
/// overlaid by non-overlapping stage samples (awake / core=N1-N2 / deep=N3 /
/// REM / unspecified), which is exactly the raw material these formulas need.

/// A single sleep-tracking interval, decoupled from HealthKit's enum so the
/// derivation is pure and unit-testable.
struct SleepInterval {
    enum Kind { case inBed, awake, asleep }
    let kind: Kind
    let start: Date
    let end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Derived per-night sleep metrics. Dates are absolute; `LiveDataBuilder`
/// formats them into the string shapes the views/models expect.
struct NightSample: Identifiable {
    var id: String { date }
    let date: String            // "yyyy-MM-dd" of the final-wake day
    let lightsOut: Date         // in-bed start (fallback: first sample start)
    let sleepOnset: Date        // first asleep start
    let finalWake: Date         // last asleep end
    let solMin: Double
    let tstMin: Int
    let wasoMin: Int
    let tibMin: Int
    let sePct: Double
    var avgHRBpm: Double? = nil  // mean heart rate during the in-bed window
    var hrvMs: Double? = nil     // mean HRV (SDNN) during the in-bed window
}

enum SleepMetrics {

    /// Nights are separated when the gap between consecutive intervals exceeds
    /// this threshold, so a daytime nap and the main night aren't merged.
    static let nightGapThreshold: TimeInterval = 3 * 60 * 60

    /// Segment a flat list of intervals into nights and derive metrics for each.
    /// Returns nights sorted oldest → newest; nights with no asleep time are dropped.
    static func nights(from intervals: [SleepInterval], calendar: Calendar = .current) -> [NightSample] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }

        var clusters: [[SleepInterval]] = []
        var current: [SleepInterval] = []
        var clusterEnd: Date?
        for iv in sorted {
            if let end = clusterEnd, iv.start.timeIntervalSince(end) > nightGapThreshold {
                clusters.append(current)
                current = []
                clusterEnd = nil
            }
            current.append(iv)
            clusterEnd = max(clusterEnd ?? iv.end, iv.end)
        }
        if !current.isEmpty { clusters.append(current) }

        return clusters.compactMap { night(from: $0, calendar: calendar) }
    }

    /// Derive one night's metrics from a cluster of overlapping intervals.
    static func night(from cluster: [SleepInterval], calendar: Calendar = .current) -> NightSample? {
        let asleep = cluster.filter { $0.kind == .asleep }
        guard let sleepOnset = asleep.map({ $0.start }).min(),
              let finalWake = asleep.map({ $0.end }).max() else { return nil }

        // Time in bed: prefer explicit in-bed samples; otherwise the full span.
        let inBed = cluster.filter { $0.kind == .inBed }
        let lightsOut = inBed.map { $0.start }.min() ?? cluster.map { $0.start }.min() ?? sleepOnset
        let bedEnd = inBed.map { $0.end }.max() ?? cluster.map { $0.end }.max() ?? finalWake
        let tibSec = max(0, bedEnd.timeIntervalSince(lightsOut))

        let tstSec = asleep.reduce(0.0) { $0 + $1.duration }

        // WASO: awake time clipped to the (onset, final-wake) window.
        let wasoSec = cluster.filter { $0.kind == .awake }.reduce(0.0) { acc, iv in
            let s = max(iv.start, sleepOnset), e = min(iv.end, finalWake)
            return acc + max(0, e.timeIntervalSince(s))
        }

        let solSec = max(0, sleepOnset.timeIntervalSince(lightsOut))
        let tibMin = Int((tibSec / 60).rounded())
        let se = tibSec > 0 ? (tstSec / tibSec * 100).rounded(toPlaces: 1) : 0

        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"

        return NightSample(
            date: df.string(from: finalWake),
            lightsOut: lightsOut,
            sleepOnset: sleepOnset,
            finalWake: finalWake,
            solMin: (solSec / 60).rounded(toPlaces: 1),
            tstMin: Int((tstSec / 60).rounded()),
            wasoMin: Int((wasoSec / 60).rounded()),
            tibMin: tibMin,
            sePct: se
        )
    }
}
