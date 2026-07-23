import Foundation

// MARK: - Core domain models (mirror the web Postgres schema)

struct UserProfile: Codable, Identifiable {
    let id: String
    var name: String
    var requiredRiseTime: String     // "06:30"
    var targetBedTime: String
    var targetWakeTime: String
    var baselineSolMin: Double
    var baselineAvgTstMin: Int
    var currentOffsetMin: Int
    var warmingMethod: String
    var phase: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case requiredRiseTime = "required_rise_time"
        case targetBedTime = "target_bed_time"
        case targetWakeTime = "target_wake_time"
        case baselineSolMin = "baseline_sol_min"
        case baselineAvgTstMin = "baseline_avg_tst_min"
        case currentOffsetMin = "current_offset_min"
        case warmingMethod = "warming_method"
        case phase
    }
}

// Thermal module ---------------------------------------------------------
struct SleepLog: Codable, Identifiable {
    var id: String { date }
    let date: String
    let lightsOut: String
    let sleepOnset: String
    let solMin: Double?
    let wakeTime: String
    let tstMin: Int
    let ritualDone: Bool
    let prescribedOffsetMin: Int?
    let phase: String
}

struct ThermalPrescription: Codable, Identifiable {
    var id: Int { block }
    let block: Int
    let prescribedOffsetMin: Int
    let warmingMethod: String
    let durationMin: Int
    let tempBand: String
    let medianSolPrior: Double?
    let action: String
    let converged: Bool
    let rationale: String
}

// CBT-I module -----------------------------------------------------------
struct CBTILog: Codable, Identifiable {
    var id: String { date }
    let date: String
    let timeToBed: String
    let sleepOnsetMin: Int
    let wasoMin: Int
    let finalWakeTime: String
    let tstMin: Int
    let tibMin: Int
    let sePct: Double?
}

struct CBTIPrescription: Codable, Identifiable {
    var id: Int { week }
    let week: Int
    let weekStart: String
    let tibMin: Int
    let wakeTime: String
    let bedTime: String
    let avgSePrior: Double?
    let action: String
    let rationale: String
}

// Calendar agent ---------------------------------------------------------
struct CalendarEvent: Codable, Identifiable {
    let id: String
    let title: String
    let startTs: String
    let endTs: String
    let type: String                 // late_night | travel | early_meeting
    let tzOffsetHours: Int?
    let direction: String?           // east | west
}

struct Adaptation: Codable, Identifiable {
    var id: String { eventId }
    let eventId: String
    let scenario: String
    let recommendation: String
    let scienceBasis: String
    let applied: Bool
    /// The LLM's personalized, plain-language "why this affects your sleep".
    /// Optional so bundled `seed.json` (which omits it) still decodes.
    var whyItAffectsSleep: String? = nil
}

// Pods / social ----------------------------------------------------------
struct PodMember: Codable, Identifiable {
    var id: String { name }
    let name: String
    let status: String               // hit | partial | miss
    let nightsHit: Int
    let streakWeeks: Int
}

struct PodWeek: Codable, Identifiable {
    var id: String { weekStart }
    let weekStart: String
    let membersHit: Int
    let allHit: Bool
    let rewardUnlocked: Bool
    let reward: String?
    let redeemed: Bool
}

struct Pod: Codable {
    let name: String
    let weeklyGoalNights: Int
    let members: [PodMember]
    let weeks: [PodWeek]
}

// Coach ------------------------------------------------------------------
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String   // mutable so coach replies can stream token-by-token
    enum Role { case user, coach }
}

// Root seed container ----------------------------------------------------
struct SeedBundle: Codable {
    let user: UserProfile
    let sleepLogs: [SleepLog]
    let prescriptions: [ThermalPrescription]
    let cbtiLogs: [CBTILog]
    let cbtiPrescriptions: [CBTIPrescription]
    let calendarEvents: [CalendarEvent]
    let adaptations: [Adaptation]
    let pod: Pod

    /// Fallback used only if the bundled seed can't be loaded, so live mode
    /// still has a valid (empty) shape to start from instead of crashing.
    static var empty: SeedBundle {
        SeedBundle(
            user: UserProfile(id: "healthkit-user", name: "You",
                              requiredRiseTime: "07:00", targetBedTime: "23:00", targetWakeTime: "07:00",
                              baselineSolMin: 0, baselineAvgTstMin: 0, currentOffsetMin: 90,
                              warmingMethod: "foot bath (40–42C, 12 min)", phase: "titration"),
            sleepLogs: [], prescriptions: [], cbtiLogs: [], cbtiPrescriptions: [],
            calendarEvents: [], adaptations: [],
            pod: Pod(name: "The Well-Rested", weeklyGoalNights: 5, members: [], weeks: []))
    }
}
