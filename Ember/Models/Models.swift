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

/// A calendar event with real `Date`s, for the day-timeline Agenda. Unlike
/// `CalendarEvent` (string timestamps, sleep-relevant only) this covers every
/// event in the fetch window — neutral ones included — so the whole day renders.
struct AgendaEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let category: String     // normalized category, or "neutral"
    var why: String? = nil

    var isSleepRelevant: Bool { category != "neutral" }
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
                isFriend: true, isCurrentUser: true, decorationID: "sleepy-cloud"),
            people: [
                BoxSpacePerson(id: "empty-box-3", name: "", monthlyScore: 0, rank: 0,
                               isFriend: false, isCurrentUser: false, decorationID: nil)
            ],
            decorations: localDecorations)
    }

    /// The backend intentionally stores only these stable IDs. Names, images,
    /// and point thresholds remain versioned with the app.
    static let localDecorations: [BoxDecoration] = [
        BoxDecoration(id: "classic-blue", name: "Classic Blue",
                      assetName: "basic_blue", requiredScore: 0),
        BoxDecoration(id: "sleepy-cloud", name: "Sleepy Cloud",
                      assetName: "sleepy_blue", requiredScore: 500),
        BoxDecoration(id: "ocean-wave", name: "Ocean Wave",
                      assetName: "happy_blue", requiredScore: 500),
        BoxDecoration(id: "midnight", name: "Midnight",
                      assetName: "moon_blue", requiredScore: 500),
        BoxDecoration(id: "forest-dream", name: "Forest Dream",
                      assetName: "dream_blue", requiredScore: 1_500),
        BoxDecoration(id: "cozy-blue", name: "Cozy Blue",
                      assetName: "cozy_blue", requiredScore: 1_500),
        BoxDecoration(id: "starlight", name: "Starlight",
                      assetName: "story_blue", requiredScore: 1_500),
        BoxDecoration(id: "royal-blue", name: "Royal Blue",
                      assetName: "royal_blue", requiredScore: 3_000),
        BoxDecoration(id: "beauty-blue", name: "Beauty Blue",
                      assetName: "beauty_blue", requiredScore: 3_000),
        BoxDecoration(id: "foodie-blue", name: "Foodie Blue",
                      assetName: "foodie_blue", requiredScore: 3_000)
    ]

    static func initial(displayName: String) -> BoxSpaceSnapshot {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let month = now.formatted(.dateTime.month(.wide))
        let nextMonth = calendar.date(
            byAdding: .month,
            value: 1,
            to: calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now)
        return BoxSpaceSnapshot(
            monthLabel: month,
            resetsAt: (nextMonth ?? now).ISO8601Format(),
            currentUser: BoxSpacePerson(
                id: "me", name: displayName, monthlyScore: 0, rank: 0,
                isFriend: true, isCurrentUser: true, decorationID: "classic-blue"),
            people: [
                BoxSpacePerson(
                    id: "empty-box", name: "", monthlyScore: 0, rank: 0,
                    isFriend: false, isCurrentUser: false, decorationID: nil)
            ],
            decorations: localDecorations)
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
    let assetName: String
    let systemImage: String?
    let requiredScore: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case assetName = "asset_name"
        case systemImage = "system_image"
        case requiredScore = "required_score"
    }

    init(
        id: String,
        name: String,
        assetName: String,
        requiredScore: Int,
        systemImage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.assetName = assetName
        self.requiredScore = requiredScore
        self.systemImage = systemImage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        systemImage = try container.decodeIfPresent(String.self, forKey: .systemImage)
        assetName = try container.decodeIfPresent(String.self, forKey: .assetName)
            ?? systemImage
            ?? id
        requiredScore = try container.decode(Int.self, forKey: .requiredScore)
    }
}

// Local Rest Journey -----------------------------------------------------
/// One explainable source of points for a day. The stable `id` is persisted so
/// the UI and a future backend can distinguish sleep, steps, energy, and
/// exercise without parsing display copy.
struct RestPointComponent: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let points: Int
    let maximumPoints: Int
}

/// A replaceable daily ledger entry. Recalculating a day from HealthKit updates
/// this entry instead of awarding the same activity a second time.
struct RestPointDay: Codable, Identifiable, Equatable {
    let id: String                 // local calendar day, yyyy-MM-dd
    let steps: Int
    let activeEnergyKcal: Int
    let exerciseMinutes: Int
    let sleepMinutes: Int?
    let components: [RestPointComponent]

    var points: Int { components.reduce(0) { $0 + $1.points } }
}

/// `points` and `skin_id` cache the latest Supabase monthly record. The daily
/// ledger stays local so HealthKit inputs remain explainable without uploading
/// raw health measurements.
struct RestJourneyProfile: Codable, Equatable {
    var points: Int
    var skinID: String?
    var dailyScores: [String: RestPointDay]

    enum CodingKeys: String, CodingKey {
        case points
        case skinID = "skin_id"
        case dailyScores = "daily_scores"
    }

    static let empty = RestJourneyProfile(points: 0, skinID: nil, dailyScores: [:])
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
