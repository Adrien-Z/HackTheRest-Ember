import Foundation

/// Grounded conversational coach. When an LLM is configured it answers from the
/// user's OWN data plus a fixed corpus of scientific sources (so citations are
/// real, never invented). Without a key it falls back to the deterministic
/// rule-based answers below, so the chat always works.
enum RestCoach {

    // MARK: - LLM system prompt (persona + citation corpus)

    /// The coach may only cite from this list — it prevents fabricated studies.
    static let systemPrompt = """
    You are EMBER's Rest Coach: a concise, evidence-based sleep coach embedded in a \
    sleep app. Answer the user's questions using (a) THEIR data provided below and \
    (b) ONLY the scientific sources in the citation list. Never invent studies, \
    statistics, or numbers that aren't in the data or the list.

    STYLE:
    - Be warm but concise: 1–3 short paragraphs, no preamble.
    - Ground every claim in the user's data or a listed source; cite as "(Author Year)".
    - Explain mechanisms plainly (e.g. why warming the skin lowers core temperature).
    - You are a coach, not a clinician. For medical concerns (insomnia disorder, apnea, \
      medication decisions) recommend consulting a healthcare professional. Only mention \
      melatonin in the 0.5–5 mg range already used by the app's jet-lag guidance.

    GENERATIVE UI — you can render native widgets inline. Emit a fenced block on its \
    own lines, with valid JSON, one widget per block:
    :::ember
    { "type": "sol_chart", "caption": "Your onset is trending down." }
    :::
    Use a widget when a visual helps (e.g. the user asks about a trend). Place text \
    before/after it. Available widgets:
    - "sol_chart" — the user's sleep-onset-latency trend (real data; no other fields needed).
    - "se_chart" — the user's sleep-efficiency trend (real data).
    - "tib_chart" — the user's weekly time-in-bed prescriptions (real data).
    - "offset_chart" — the user's warming-offset titration by block (real data).
    - "stats" — key numbers: "items":[{"label","value","caption"?}] using ONLY numbers \
      from the data below.
    - "line" | "bar" — a custom chart: "title","yLabel","points":[{"x","y"}] using ONLY \
      real numbers from the data below — never invent data points.
    - "checklist" — tonight's actions: "steps":["…"].
    - "callout" — a highlighted tip: put the text in "caption".
    Prefer the four app-bound charts for the user's own trends (they always plot accurate \
    data). All widgets support optional "title" and "caption". Keep surrounding text short.

    CITATION LIST (use these only):
    - Haghayegh 2019 — meta-analysis (17 studies): passive body heating 1–2 h before bed \
      shortens sleep-onset latency by ~9 min via core-temperature drop.
    - AASM CBT-I / Spielman sleep restriction — match time-in-bed to actual sleep, then \
      widen: sleep efficiency ≥90% → +15 min, 85–90% → hold, <85% → restrict toward actual sleep.
    - Windred 2024 — UK Biobank (~60,000 people): sleep REGULARITY predicts mortality more \
      strongly than duration; irregular timing raises risk 20–48%.
    - Wittmann & Roenneberg 2006 — "social jetlag": the gap between biological and social \
      sleep timing (sleep-midpoint shift) is linked to metabolic and cardiovascular risk.
    - Eastman & Burgess; St Hilaire 2014; Herxheimer Cochrane 2002 — jet lag: timed bright \
      light + melatonin; eastward needs a phase advance (harder), westward a phase delay.
    - Chaput 2020 — sleep duration/regularity recommendations; anchoring a consistent wake \
      time protects performance.
    - Carney 2012 — Consensus Sleep Diary: standard definitions of SOL, WASO, TST, TIB, and \
      sleep efficiency (TST/TIB).
    """

    // MARK: - Context snapshot fed to the LLM

    /// A compact, current view of everything the coach should know. Rebuilt each
    /// turn so answers reflect the latest data / mode.
    @MainActor static func contextSnapshot(store: DataStore) -> String {
        var lines: [String] = []
        lines.append("DATA SOURCE: \(store.isSampleData ? "sample/demo data" : "live Apple Health data")")

        let u = store.user
        lines.append("PROFILE: name=\(u.name), target bed=\(u.targetBedTime), target wake=\(u.targetWakeTime), warming method=\(u.warmingMethod), phase=\(u.phase), current warming offset=\(u.currentOffsetMin) min, baseline SOL=\(String(format: "%.1f", u.baselineSolMin)) min, baseline avg TST=\(u.baselineAvgTstMin) min.")

        if let rx = store.currentThermalRx {
            lines.append("THERMAL (warming) — current: offset \(rx.prescribedOffsetMin) min before bed via \(rx.warmingMethod), action=\(rx.action), converged=\(rx.converged). Rationale: \(rx.rationale)")
        }
        let recentSOL = store.sleepLogs.compactMap { $0.solMin }.suffix(7)
        if !recentSOL.isEmpty {
            let avg = recentSOL.reduce(0,+) / Double(recentSOL.count)
            lines.append("Recent sleep-onset latency (last \(recentSOL.count) nights, min): \(recentSOL.map { String(format: "%.0f", $0) }.joined(separator: ", ")) (avg \(String(format: "%.0f", avg))).")
        }

        if let rx = store.currentCBTIRx {
            let se = rx.avgSePrior.map { String(format: "%.1f%%", $0) } ?? "—"
            lines.append("CBT-I (sleep efficiency) — current: time-in-bed \(fmtDur(rx.tibMin)), bed \(rx.bedTime), wake \(rx.wakeTime), action=\(rx.action), prior-week efficiency \(se). Rationale: \(rx.rationale)")
        }
        let recentSE = store.cbtiLogs.compactMap { $0.sePct }.suffix(7)
        if !recentSE.isEmpty {
            lines.append("Recent sleep efficiency (last \(recentSE.count) nights, %): \(recentSE.map { String(format: "%.0f", $0) }.joined(separator: ", ")).")
        }

        if let tst = store.healthLastNightTST { lines.append("Last night: \(fmtDur(tst)) asleep.") }
        if let hr = store.lastNightHR { lines.append("Overnight avg heart rate: \(Int(hr)) bpm.") }
        if let hrv = store.lastNightHRV { lines.append("Overnight HRV (SDNN): \(Int(hrv)) ms.") }

        if !store.adaptations.isEmpty {
            lines.append("UPCOMING CALENDAR ADAPTATIONS:")
            for a in store.adaptations.prefix(6) {
                lines.append("  • [\(a.scenario)] \(a.recommendation)")
            }
        }

        let hit = store.pod.members.filter { $0.status == "hit" }.count
        lines.append("POD: \(hit)/\(store.pod.members.count) members hit their goal in \(store.pod.name) (goal \(store.pod.weeklyGoalNights) nights). The pod only sees a status ring, never raw sleep times.")

        return lines.joined(separator: "\n")
    }

    // MARK: - Rule-based fallback (no API key / LLM unreachable)

    @MainActor static func answer(to question: String, store: DataStore, adaptations: [Adaptation]) async -> String {
        let q = question.lowercased()

        // CBT-I / time-in-bed
        if q.contains("time-in-bed") || q.contains("time in bed") || q.contains("efficiency") || q.contains("restrict") {
            if let rx = store.currentCBTIRx {
                let se = rx.avgSePrior.map { String(format: "%.1f%%", $0) } ?? "—"
                return "Your time-in-bed is \(fmtDur(rx.tibMin)) this week. \(rx.rationale) The rule: efficiency ≥90% widens the window +15 min, 85–90% holds, and <85% restricts it toward your actual sleep. Your prior-week efficiency was \(se)."
            }
        }
        // Thermal / warming
        if q.contains("warm") || q.contains("offset") || q.contains("bath") || q.contains("onset") {
            if let rx = store.currentThermalRx {
                return "Start your \(store.user.warmingMethod) about \(rx.prescribedOffsetMin) min before bed. \(rx.rationale) Warming the periphery pulls heat away from your core; the core-temperature drop is a physiological trigger for sleep onset."
            }
        }
        // Travel / jet lag
        if q.contains("flight") || q.contains("jet") || q.contains("travel") || q.contains("trip") {
            if let a = adaptations.first(where: { $0.scenario.contains("travel") }) {
                return "\(a.recommendation)\n\nWhy: \(a.scienceBasis)"
            }
        }
        // Regularity / naps / late night
        if q.contains("nap") || q.contains("late") || q.contains("regular") || q.contains("concert") {
            if let a = adaptations.first(where: { $0.scenario == "social_jetlag" || $0.scenario == "late_night" }) {
                return "\(a.recommendation)\n\nWhy: \(a.scienceBasis)"
            }
        }
        // Pod / reward
        if q.contains("pod") || q.contains("reward") || q.contains("friend") {
            let hit = store.pod.members.filter { $0.status == "hit" }.count
            return "\(hit) of \(store.pod.members.count) in \(store.pod.name) hit their goal this week. When everyone reaches \(store.pod.weeklyGoalNights) on-target nights, the pod unlocks a Blue Box reward. Your pod only sees a status ring — never your actual sleep times."
        }
        // Default
        return "I can explain any part of your plan — your warming offset, your time-in-bed window, upcoming calendar adaptations, or your pod. Try one of the suggestions below."
    }
}
