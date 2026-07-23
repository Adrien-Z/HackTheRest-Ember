import Foundation

/// Grounded conversational coach. Answers from the user's OWN data + the
/// encoded science rules — no hallucinated facts. Designed as a drop-in that
/// can later be replaced by a live LLM call (send `store` context + question + adaptations).
enum RestCoach {
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
        if q.contains("flight") || q.contains("jet") || q.contains("london") || q.contains("travel") {
            if let a = adaptations.first(where: { $0.scenario.contains("travel") }) {
                return "\(a.recommendation)\n\nWhy: \(a.scienceBasis)"
            }
        }
        // Regularity / naps / late night
        if q.contains("nap") || q.contains("late") || q.contains("regular") || q.contains("concert") {
            if let a = adaptations.first(where: { $0.scenario == "late_night" }) {
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
