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

// Box Space / monthly social score ---------------------------------------
struct BoxSpaceSnapshot: Codable {
    let monthLabel: String
    let resetsAt: String
    var currentUser: BoxSpacePerson
    let people: [BoxSpacePerson]
    let decorations: [BoxDecoration]

    enum CodingKeys: String, CodingKey {
        case monthLabel = "month_label"
        case resetsAt = "resets_at"
        case currentUser = "current_user"
        case people, decorations
    }

    static var sample: BoxSpaceSnapshot {
        BoxSpaceSnapshot(
            monthLabel: "July",
            resetsAt: "2026-08-01T00:00:00+08:00",
            currentUser: BoxSpacePerson(
                id: "me", name: "Alex", monthlyScore: 2_480, rank: 2,
                isFriend: true, isCurrentUser: true, decorationID: "sleep-cap"),
            people: [
                BoxSpacePerson(id: "maya", name: "Maya", monthlyScore: 2_760, rank: 1,
                               isFriend: true, isCurrentUser: false, decorationID: "star"),
                BoxSpacePerson(id: "jordan", name: "Jordan", monthlyScore: 2_210, rank: 3,
                               isFriend: true, isCurrentUser: false, decorationID: "plant"),
                BoxSpacePerson(id: "sam", name: "Sam", monthlyScore: 1_840, rank: 5,
                               isFriend: true, isCurrentUser: false, decorationID: nil),
                BoxSpacePerson(id: "river", name: "River", monthlyScore: 1_520, rank: 7,
                               isFriend: false, isCurrentUser: false, decorationID: nil),
                BoxSpacePerson(id: "noa", name: "Noa", monthlyScore: 1_190, rank: 9,
                               isFriend: false, isCurrentUser: false, decorationID: nil),
                BoxSpacePerson(id: "empty-box-3", name: "", monthlyScore: 0, rank: 0,
                               isFriend: false, isCurrentUser: false, decorationID: nil)
            ],
            decorations: [
                BoxDecoration(id: "sleep-cap", name: "Sleep cap",
                              systemImage: "moon.stars.fill", requiredScore: 500),
                BoxDecoration(id: "plant", name: "Little plant",
                              systemImage: "leaf.fill", requiredScore: 1_500),
                BoxDecoration(id: "star", name: "Dream star",
                              systemImage: "sparkles", requiredScore: 2_500),
                BoxDecoration(id: "crown", name: "Moon crown",
                              systemImage: "crown.fill", requiredScore: 3_000)
            ])
    }
}

struct BoxSpacePerson: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let monthlyScore: Int
    let rank: Int
    let isFriend: Bool
    let isCurrentUser: Bool
    var decorationID: String?

    enum CodingKeys: String, CodingKey {
        case id, name, rank
        case monthlyScore = "monthly_score"
        case isFriend = "is_friend"
        case isCurrentUser = "is_current_user"
        case decorationID = "decoration_id"
    }
}

struct BoxDecoration: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let systemImage: String
    let requiredScore: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case systemImage = "system_image"
        case requiredScore = "required_score"
    }
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
