import Foundation

/// Pure, testable protocol engines — the scientific core of EMBER.
/// These mirror the web build's pure functions exactly so the two clients agree.
enum RestAlgorithms {

    // MARK: - CBT-I Sleep Restriction (Module B)
    //
    // Sleep Efficiency = Total Sleep Time / Time In Bed.
    // Weekly titration rule (Spielman sleep-restriction therapy):
    //   avg SE >= 90%  -> increase time-in-bed by 15 min
    //   85% <= SE < 90% -> hold
    //   avg SE < 85%   -> restrict time-in-bed to actual average sleep (floor 300 min / 5h)

    static let cbtiTibFloorMin = 300

    static func computeSE(tstMin: Int, tibMin: Int) -> Double {
        guard tibMin > 0 else { return 0 }
        return (Double(tstMin) / Double(tibMin) * 100).rounded(toPlaces: 1)
    }

    enum CBTIAction: String { case increase, hold, restrict, baseline }

    struct CBTIDecision {
        let nextTibMin: Int
        let action: CBTIAction
        let rationale: String
    }

    /// Given the prior week's average SE and average TST, prescribe next week's TIB.
    static func nextTIB(currentTibMin: Int, avgSE: Double, avgTstMin: Int) -> CBTIDecision {
        if avgSE >= 90 {
            let next = currentTibMin + 15
            return CBTIDecision(nextTibMin: next, action: .increase,
                rationale: String(format: "SE %.1f%% (≥90%%) — increase time-in-bed +15 to %d min.", avgSE, next))
        } else if avgSE >= 85 {
            return CBTIDecision(nextTibMin: currentTibMin, action: .hold,
                rationale: String(format: "SE %.1f%% (85–90%% hold zone) — hold at %d min.", avgSE, currentTibMin))
        } else {
            let next = max(cbtiTibFloorMin, Int((Double(avgTstMin) / 5).rounded()) * 5)
            return CBTIDecision(nextTibMin: next, action: .restrict,
                rationale: String(format: "SE %.1f%% (<85%%) — restrict time-in-bed to actual sleep (%d min) to consolidate.", avgSE, next))
        }
    }

    // MARK: - Thermal Wind-Down titration (Module A)
    //
    // Warming the periphery before bed drops core temperature and shortens
    // Sleep Onset Latency (SOL). We titrate the WARMING OFFSET (minutes before
    // bed to start the ritual) to hit a target SOL, hill-climbing from a
    // literature default of 90 min (Haghayegh 2019 meta-analysis).

    static let solTargetMin: Double = 20
    static let offsetFloorMin = 30
    static let offsetStepMin = 15

    enum ThermalAction: String { case initiation, `continue`, holdConverged = "hold_converged" }

    struct ThermalDecision {
        let nextOffsetMin: Int
        let action: ThermalAction
        let converged: Bool
        let rationale: String
    }

    /// Given the median SOL observed on the current offset, prescribe the next offset.
    static func nextOffset(currentOffsetMin: Int, medianSOL: Double, priorMedianSOL: Double?) -> ThermalDecision {
        // Converged: SOL comfortably under target -> lock the personalized offset.
        if medianSOL < solTargetMin {
            return ThermalDecision(nextOffsetMin: currentOffsetMin, action: .holdConverged, converged: true,
                rationale: String(format: "Median SOL %.1f min < %.0f target → lock personalized offset at %d min.", medianSOL, solTargetMin, currentOffsetMin))
        }
        // Still above target -> step the offset down toward bedtime (tighter coupling).
        let next = max(offsetFloorMin, currentOffsetMin - offsetStepMin)
        let trend: String
        if let p = priorMedianSOL {
            trend = medianSOL < p ? String(format: ", improving vs prior (%.1f)", p) : String(format: ", vs prior (%.1f)", p)
        } else { trend = "" }
        return ThermalDecision(nextOffsetMin: next, action: .continue, converged: false,
            rationale: String(format: "Median SOL %.1f min%@ → continue toward %d min.", medianSOL, trend, next))
    }

    // MARK: - Calendar-aware adaptation (the proactive agent)
    //
    // Maps a calendar event to a science-grounded schedule adaptation. Rules are
    // literature-anchored (regularity > duration; directional light/melatonin for
    // travel; anchored wake time for early events).

    struct AdaptationResult {
        let scenario: String
        let recommendation: String
        let scienceBasis: String
    }

    static func adapt(for event: CalendarEvent, targetWake: String) -> AdaptationResult {
        switch event.type {
        case "late_night":
            return AdaptationResult(
                scenario: "late_night",
                recommendation: "Keep your \(targetWake) wake time tomorrow — do not sleep in past +30 min. Take a 20–30 min nap between 13:00 and 15:00 if you feel drowsy.",
                scienceBasis: "Sleep REGULARITY predicts health more than duration — irregular wake times raise mortality risk 20–48% (Windred 2024). A short nap recovers alertness better than sleeping in.")
        case "travel":
            if event.direction == "east" {
                let h = event.tzOffsetHours ?? 0
                return AdaptationResult(
                    scenario: "travel_east",
                    recommendation: "Eastward jet lag (\(h)h): shift bed & wake ~1h EARLIER starting 2–3 days before departure. At destination seek bright light in the MORNING and consider 0.5–5 mg melatonin near local bedtime.",
                    scienceBasis: "Timed bright light + melatonin is the validated anti-jet-lag protocol; direction sets timing — eastward = morning light + phase advance (Eastman & Burgess; St Hilaire 2014; Herxheimer Cochrane 2002).")
            } else {
                let h = event.tzOffsetHours ?? 0
                return AdaptationResult(
                    scenario: "travel_west",
                    recommendation: "Westward jet lag (\(h)h): shift bed & wake ~1h LATER for a few days before departure. At destination seek bright light in the EVENING to delay your clock.",
                    scienceBasis: "Westward travel requires a phase DELAY — evening light delays the circadian clock (Eastman & Burgess; St Hilaire 2014).")
            }
        case "early_meeting":
            return AdaptationResult(
                scenario: "early_meeting",
                recommendation: "Move tonight's whole routine — including the warming ritual — 90 minutes earlier so you still get a full sleep opportunity before the meeting.",
                scienceBasis: "Anchoring a consistent wake time and a full sleep opportunity protects performance and circadian alignment (Chaput 2020).")
        default:
            return AdaptationResult(scenario: "general",
                recommendation: "Keep a consistent bed and wake time around this event.",
                scienceBasis: "Regularity is the strongest modifiable sleep-health lever (Windred 2024).")
        }
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let d = pow(10.0, Double(places))
        return (self * d).rounded() / d
    }
}
