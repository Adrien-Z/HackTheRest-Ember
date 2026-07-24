import Foundation

/// Circadian-regularity metrics derived from the user's own sleep timing —
/// the science EMBER coaches on but most trackers ignore. Pure and testable:
/// everything operates on reconstructed sleep periods, no HealthKit or UI.
///
/// Sources (mirrored in the coach's citation corpus):
///   • Phillips 2017 (Scientific Reports) — Sleep Regularity Index (SRI).
///   • Windred 2024 (UK Biobank) — regularity predicts mortality above duration.
///   • Wittmann & Roenneberg 2006 — social jetlag = weekend−weekday midpoint gap.
enum SleepScience {

    /// One night reduced to the two instants the regularity math needs.
    struct SleepPeriod {
        let onset: Date
        let wake: Date
        /// Clock midpoint in minutes-of-day [0,1440), wrap-safe.
        let midpointMinOfDay: Int
        /// Weekday of the wake day (1 = Sunday … 7 = Saturday, Gregorian).
        let wakeWeekday: Int
        /// "yyyy-MM-dd" of the wake day, for chart labels.
        let dayLabel: String
    }

    struct RegularityReport {
        let sri: Double?                 // 0–100 (higher = more regular)
        let socialJetlagMin: Double?     // |weekend − weekday| midpoint gap
        let midpointStdevMin: Double?    // night-to-night spread of the midpoint
        let avgMidpoint: String?         // "HH:mm" typical sleep midpoint
        let nights: Int
        let midpoints: [MidpointPoint]   // per-night series for charting

        struct MidpointPoint: Identifiable {
            var id: String { day }
            let day: String              // "yyyy-MM-dd"
            let minOfDay: Int            // midpoint clock time
            let isWeekend: Bool
        }
    }

    // MARK: - Period reconstruction

    /// Rebuild sleep periods from the string-based `SleepLog`s the store already
    /// holds (works identically for sample and live data). `sleepOnset`/`wakeTime`
    /// are "HH:mm"; `date` is the final-wake day. An evening onset (hour ≥ 12)
    /// belongs to the day before the wake day; a past-midnight onset stays on it.
    static func periods(from logs: [SleepLog], calendar: Calendar = .current) -> [SleepPeriod] {
        let df = DateFormatter()
        df.calendar = calendar; df.timeZone = calendar.timeZone; df.dateFormat = "yyyy-MM-dd"

        return logs.compactMap { log in
            guard let wakeDay = df.date(from: log.date),
                  let (oh, om) = hhmm(log.sleepOnset),
                  let (wh, wm) = hhmm(log.wakeTime) else { return nil }
            guard let wake = calendar.date(bySettingHour: wh, minute: wm, second: 0, of: wakeDay)
            else { return nil }
            let onsetBaseDay = oh >= 12 ? calendar.date(byAdding: .day, value: -1, to: wakeDay)! : wakeDay
            guard let onset = calendar.date(bySettingHour: oh, minute: om, second: 0, of: onsetBaseDay),
                  onset < wake else { return nil }

            // Midpoint as a clock time, computed on the real span then mapped to
            // minutes-of-day so a 01:30 midpoint reads as 90, not a huge number.
            let mid = onset.addingTimeInterval(wake.timeIntervalSince(onset) / 2)
            let mc = calendar.dateComponents([.hour, .minute], from: mid)
            let midMin = ((mc.hour ?? 0) * 60 + (mc.minute ?? 0)) % 1440
            let weekday = calendar.component(.weekday, from: wakeDay)
            return SleepPeriod(onset: onset, wake: wake, midpointMinOfDay: midMin,
                               wakeWeekday: weekday, dayLabel: log.date)
        }
        .sorted { $0.onset < $1.onset }
    }

    // MARK: - Report

    static func report(logs: [SleepLog], calendar: Calendar = .current) -> RegularityReport {
        let p = periods(from: logs, calendar: calendar)
        guard p.count >= 2 else {
            return RegularityReport(sri: nil, socialJetlagMin: nil, midpointStdevMin: nil,
                                    avgMidpoint: nil, nights: p.count, midpoints: [])
        }

        let mids = p.map { RegularityReport.MidpointPoint(
            day: $0.dayLabel, minOfDay: $0.midpointMinOfDay,
            isWeekend: $0.wakeWeekday == 1 || $0.wakeWeekday == 7) }

        return RegularityReport(
            sri: sleepRegularityIndex(p, calendar: calendar),
            socialJetlagMin: socialJetlagMin(p),
            midpointStdevMin: circularStdevMin(p.map { $0.midpointMinOfDay }),
            avgMidpoint: circularMeanClock(p.map { $0.midpointMinOfDay }),
            nights: p.count,
            midpoints: mids)
    }

    // MARK: - Sleep Regularity Index (Phillips 2017)

    /// Probability of being in the same state (asleep/awake) at two times 24 h
    /// apart, sampled on an epoch grid and rescaled to 0–100 (100 = identical
    /// every day). Negative theoretical values are clamped to 0.
    static func sleepRegularityIndex(_ periods: [SleepPeriod],
                                     epochMinutes: Int = 5,
                                     calendar: Calendar = .current) -> Double? {
        guard let first = periods.first?.onset, let last = periods.last?.wake,
              last > first else { return nil }
        let epoch = TimeInterval(epochMinutes * 60)
        let dayEpochs = Int((24 * 3600) / epoch)

        // Rasterize the asleep timeline into a boolean epoch grid.
        var t = first
        var grid: [Bool] = []
        while t < last {
            let asleep = periods.contains { $0.onset <= t && t < $0.wake }
            grid.append(asleep)
            t = t.addingTimeInterval(epoch)
        }
        guard grid.count > dayEpochs else { return nil }

        var concordant = 0, pairs = 0
        for i in 0..<(grid.count - dayEpochs) {
            if grid[i] == grid[i + dayEpochs] { concordant += 1 }
            pairs += 1
        }
        guard pairs > 0 else { return nil }
        let sri = 200.0 * (Double(concordant) / Double(pairs)) - 100.0
        return max(0, (sri).rounded(toPlaces: 0))
    }

    // MARK: - Social jetlag (Wittmann & Roenneberg 2006)

    /// |mean weekend midpoint − mean weekday midpoint| in minutes. Needs at least
    /// one weekend and one weekday night; otherwise nil.
    static func socialJetlagMin(_ periods: [SleepPeriod]) -> Double? {
        let weekend = periods.filter { $0.wakeWeekday == 1 || $0.wakeWeekday == 7 }.map { $0.midpointMinOfDay }
        let weekday = periods.filter { !($0.wakeWeekday == 1 || $0.wakeWeekday == 7) }.map { $0.midpointMinOfDay }
        guard !weekend.isEmpty, !weekday.isEmpty,
              let mf = circularMeanMin(weekend), let mw = circularMeanMin(weekday) else { return nil }
        // Shorter interval around the clock (never more than 12 h apart).
        let diff = abs(mf - mw)
        return Double(min(diff, 1440 - diff)).rounded(toPlaces: 0)
    }

    // MARK: - Circular statistics for clock times

    /// Circular mean of minutes-of-day, returned in [0,1440). Averaging clock
    /// times on the unit circle avoids the 23:50/00:10 → noon artifact.
    private static func circularMeanMin(_ mins: [Int]) -> Double? {
        guard !mins.isEmpty else { return nil }
        let angles = mins.map { Double($0) / 1440 * 2 * .pi }
        let s = angles.map(sin).reduce(0,+) / Double(angles.count)
        let c = angles.map(cos).reduce(0,+) / Double(angles.count)
        var a = atan2(s, c)
        if a < 0 { a += 2 * .pi }
        return a / (2 * .pi) * 1440
    }

    private static func circularMeanClock(_ mins: [Int]) -> String? {
        guard let m = circularMeanMin(mins) else { return nil }
        let t = Int(m.rounded()) % 1440
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    /// Circular standard deviation (minutes) of clock times.
    private static func circularStdevMin(_ mins: [Int]) -> Double? {
        guard mins.count >= 2 else { return nil }
        let angles = mins.map { Double($0) / 1440 * 2 * .pi }
        let s = angles.map(sin).reduce(0,+) / Double(angles.count)
        let c = angles.map(cos).reduce(0,+) / Double(angles.count)
        let r = (s * s + c * c).squareRoot()
        guard r > 0 else { return nil }
        let stdRad = (-2 * Foundation.log(r)).squareRoot()
        return (stdRad / (2 * .pi) * 1440).rounded(toPlaces: 0)
    }

    private static func hhmm(_ s: String) -> (Int, Int)? {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return (parts[0], parts[1])
    }
}
