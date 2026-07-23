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
        // Accept both the LLM's category vocabulary and the legacy seed strings.
        switch normalizedCategory(event.type) {
        case "social_jetlag":
            return AdaptationResult(
                scenario: "social_jetlag",
                recommendation: "Keep your \(targetWake) wake time — don't sleep in past +30 min even after a late night. If you're drowsy, take a 20–30 min nap between 13:00 and 15:00 instead of extending sleep.",
                scienceBasis: "A late social night shifts your sleep MIDPOINT later; catching up by sleeping in creates 'social jetlag' — a recurring misalignment of biological vs social time linked to metabolic and cardiovascular risk (Wittmann & Roenneberg 2006). Anchoring wake time protects regularity, the strongest sleep-health lever (Windred 2024).")

        case "timezone_travel":
            let h = abs(event.tzOffsetHours ?? 0)
            if event.direction == "east" {
                let days = max(1, h)   // ~1 time zone per day eastward
                return AdaptationResult(
                    scenario: "travel_east",
                    recommendation: "Eastward across \(h)h (phase ADVANCE — the harder direction, ~\(days) day(s) to adjust): shift bed & wake ~1h EARLIER each day for 2–3 days before departure. At the destination seek bright light in the MORNING and take 0.5–5 mg melatonin at local bedtime.",
                    scienceBasis: "Eastward travel needs a phase advance, which re-entrains slower (~1 zone/day) than westward (~1.5). Light timed after your core-temp minimum (≈2–3 h before habitual wake) advances the clock; morning light + evening melatonin is the validated protocol (Eastman & Burgess; St Hilaire 2014; Herxheimer Cochrane 2002).")
            } else {
                return AdaptationResult(
                    scenario: "travel_west",
                    recommendation: "Westward across \(h)h (phase DELAY — the easier direction, ~1.5 zones/day): shift bed & wake ~1h LATER for a few days before departure. At the destination seek bright light in the EVENING to delay your clock.",
                    scienceBasis: "Westward travel needs a phase delay, which the body does more readily than an advance. Evening bright light (before your core-temp minimum) delays the circadian clock (Eastman & Burgess; St Hilaire 2014).")
            }

        case "early_obligation":
            return AdaptationResult(
                scenario: "early_obligation",
                recommendation: "Move tonight's whole routine — including the warming ritual — about 90 minutes earlier so you still get a full sleep opportunity before this early start.",
                scienceBasis: "Anchoring a consistent wake time and protecting a full sleep opportunity guards performance and circadian alignment; truncating the night ahead of an early start accrues sleep debt (Chaput 2020).")

        case "demanding_event":
            return AdaptationResult(
                scenario: "demanding_event",
                recommendation: "Protect a full sleep opportunity the night before, and keep your \(targetWake) wake time — don't trade sleep for extra prep the night before.",
                scienceBasis: "Sleep before high-stakes performance supports memory consolidation and next-day cognition; regularity predicts better outcomes than a single long night (Windred 2024).")

        default:
            return AdaptationResult(scenario: "general",
                recommendation: "Keep a consistent bed and wake time around this event.",
                scienceBasis: "Regularity is the strongest modifiable sleep-health lever (Windred 2024).")
        }
    }

    /// Map legacy seed categories onto the current vocabulary.
    static func normalizedCategory(_ type: String) -> String {
        switch type {
        case "late_night": return "social_jetlag"
        case "travel": return "timezone_travel"
        case "early_meeting": return "early_obligation"
        default: return type
        }
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let d = pow(10.0, Double(places))
        return (self * d).rounded() / d
    }
}
