import Foundation
import UserNotifications

/// Where the app's data comes from.
enum DataSourceMode: String {
    case sample   // bundled seed.json — demo content so the app is never empty
    case live     // derived from Apple Health (+ EventKit) on this device
}

/// Central observable store. Holds either the bundled sample data or live data
/// derived from Apple Health / EventKit, chosen by an explicit mode toggle in
/// Settings (no automatic fallback). Box Space uses its own backend snapshot.
@MainActor
final class DataStore: ObservableObject {
    @Published var user: UserProfile
    @Published var sleepLogs: [SleepLog] = []
    @Published var prescriptions: [ThermalPrescription] = []
    @Published var cbtiLogs: [CBTILog] = []
    @Published var cbtiPrescriptions: [CBTIPrescription] = []
    @Published var calendarEvents: [CalendarEvent] = []
    @Published var adaptations: [Adaptation] = []
    /// Every event in the fetch window (neutral included), for the day timeline.
    @Published var agendaEvents: [AgendaEvent] = []
    /// The user's currently adjusted plan for tonight, shared between Agenda and Today.
    @Published var tonightPlan: DayPlan? = nil
    /// When on, injects a set of illustrative events anchored to today so the
    /// Agenda can be demoed without a real calendar. Toggled in Settings.
    @Published var demoEventsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(demoEventsEnabled, forKey: Keys.demoEvents)
            applyAgenda()
        }
    }
    /// The real (or seed-derived) events, before any demo events are mixed in.
    private var baseAgenda: [AgendaEvent] = []
    @Published var regularity: SleepScience.RegularityReport =
        SleepScience.RegularityReport(sri: nil, socialJetlagMin: nil, midpointStdevMin: nil,
                                      avgMidpoint: nil, nights: 0, midpoints: [])
    @Published var pod: Pod                    // always sample data
    @Published var boxSpace: BoxSpaceSnapshot
    @Published private(set) var restJourney: RestJourneyProfile
    @Published var boxSpaceLoading = false
    @Published var boxSpaceError: String? = nil
    @Published private(set) var selectingSkinID: String? = nil
    @Published private(set) var completedPointEvents: Set<String> = []
    @Published private(set) var claimedBlueBoxRewardIDs: Set<String> = []
    @Published var chat: [ChatMessage] = []
    /// Set by other screens ("Ask the coach") so CoachView can auto-send on appear.
    @Published var pendingCoachQuestion: String? = nil
    /// Separate anxiety/brain-dump thread for Rest Lab.
    @Published var mindChat: [ChatMessage] = []
    @Published var mindReminderItems: [String] = []

    // Live Apple Health readout (nil until authorized + fetched)
    @Published var healthLastNightTST: Int? = nil
    @Published var lastNightHR: Double? = nil     // mean overnight heart rate (bpm)
    @Published var lastNightHRV: Double? = nil    // mean overnight HRV SDNN (ms)
    @Published var lastNightWristTempC: Double? = nil   // Apple Watch sleeping wrist temp
    @Published var wristTempBaselineC: Double? = nil    // mean of recent nights (baseline)
    /// Raw, locally-derived Apple Health nights used by Today health insights.
    @Published private(set) var recentHealthNights: [NightSample] = []
    /// Hourly Apple Health inputs used for the current-day energy estimate.
    @Published private(set) var todayEnergyDay: DailyEnergyDay? = nil
    @Published var healthAuthorized: Bool = false
    /// Optional local forecast layer for heat/humidity sleep friction. Not diagnostic.
    @Published var sleepClimate: SleepClimateSnapshot? = nil

    // Data-source state
    @Published private(set) var mode: DataSourceMode
    @Published var isLoading = false
    /// In live mode, whether the last fetch actually produced any sleep nights.
    @Published var liveHasData = false

    // User-editable settings used when building live data.
    @Published var displayName: String
    @Published var warmingMethod: String

    // LLM calendar categorization (OpenRouter by default).
    @Published var llmModel: String
    @Published var llmBaseURL: String
    @Published var aiConfigured: Bool = false      // API key present in Keychain
    @Published var aiError: String? = nil

    private let seed: SeedBundle
    private let communityService = BoxCommunityService()
    private var communityRefreshInProgress = false

    private enum Keys {
        static let mode = "ember.dataSourceMode"
        static let name = "ember.displayName"
        static let warming = "ember.warmingMethod"
        static let llmModel = "ember.llmModel"
        static let llmBaseURL = "ember.llmBaseURL"
        static let apiKeyAccount = "openrouter.apiKey"   // Keychain account
        static let calendarCache = "ember.calendarCategorizations"
        static let calendarOverrides = "ember.calendarOverrides"   // eventId → category
        static let demoEvents = "ember.demoAgendaEvents"
        static let restJourney = "ember.restJourney.v1"
        static let blueBoxRewards = "ember.blueBoxRewards.claimed.v1"
        static let mindChat = "ember.mindDump.chat.v1"
        static let mindReminderItems = "ember.mindDump.reminderItems.v1"
        static let mindReminder = "ember.mindDump.tomorrowReminder"
    }

    init() {
        let bundleSeed = DataStore.loadSeed()
        seed = bundleSeed
        let d = UserDefaults.standard
        mode = DataSourceMode(rawValue: d.string(forKey: Keys.mode) ?? "") ?? .sample
        displayName = d.string(forKey: Keys.name) ?? bundleSeed.user.name
        warmingMethod = d.string(forKey: Keys.warming) ?? bundleSeed.user.warmingMethod
        llmModel = d.string(forKey: Keys.llmModel) ?? LLMClient.defaultModel
        llmBaseURL = d.string(forKey: Keys.llmBaseURL) ?? LLMClient.defaultBaseURL
        demoEventsEnabled = d.bool(forKey: Keys.demoEvents)
        aiConfigured = Keychain.load(Keys.apiKeyAccount)?.isEmpty == false
        user = bundleSeed.user
        pod = bundleSeed.pod
        boxSpace = .initial(
            displayName: d.string(forKey: Keys.name) ?? bundleSeed.user.name)
        restJourney = Self.loadRestJourney()
        claimedBlueBoxRewardIDs = Set(d.stringArray(forKey: Keys.blueBoxRewards) ?? [])
        chat = [ChatMessage(role: .coach,
            content: "Hi \(displayName) — I'm your rest coach. Ask me why any prescription changed, or tap a suggested question below.")]
        mindChat = Self.loadMindChat()
        if mindChat.isEmpty {
            mindChat = [Self.mindDumpOpeningMessage]
        }
        mindReminderItems = Self.loadMindReminderItems()
        if mode == .sample { applySample() }
        applyLocalJourneyToBoxSpace()
    }

    /// Sample data may still be missing from the bundle in unusual build setups;
    /// return empty defaults rather than crashing so live mode remains usable.
    /// Parse a seed timestamp like "2026-07-17 21:00:00+00" into a Date.
    static func parseSeedTs(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"] {
            f.dateFormat = fmt
            if let d = f.date(from: s.replacingOccurrences(of: "+00", with: "+0000")) { return d }
        }
        return nil
    }

    static func loadSeed() -> SeedBundle {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bundle = try? JSONDecoder().decode(SeedBundle.self, from: data) else {
            return SeedBundle.empty
        }
        return bundle
    }

    var isSampleData: Bool { mode == .sample }

    // MARK: - Mode & refresh

    func setMode(_ newMode: DataSourceMode, health: HealthManager, calendar: CalendarService) async {
        guard newMode != mode else { return }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: Keys.mode)
        await refresh(health: health, calendar: calendar)
    }

    func persistSettings() {
        UserDefaults.standard.set(displayName, forKey: Keys.name)
        UserDefaults.standard.set(warmingMethod, forKey: Keys.warming)
        UserDefaults.standard.set(llmModel, forKey: Keys.llmModel)
        UserDefaults.standard.set(llmBaseURL, forKey: Keys.llmBaseURL)
    }

    /// The Supabase account is the single source of truth for the user's name.
    /// Mirror it into every local model that can render a personal greeting.
    func applyAuthenticatedDisplayName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        displayName = trimmedName
        user.name = trimmedName
        UserDefaults.standard.set(trimmedName, forKey: Keys.name)
        if let firstCoachMessage = chat.firstIndex(where: { $0.role == .coach }) {
            chat[firstCoachMessage].content = "Hi \(trimmedName) — I'm your rest coach. Ask me why any prescription changed, or tap a suggested question below."
        }
        boxSpace.currentUser = BoxSpacePerson(
            id: boxSpace.currentUser.id,
            name: trimmedName,
            monthlyScore: restJourney.points,
            rank: boxSpace.currentUser.rank,
            isFriend: boxSpace.currentUser.isFriend,
            isCurrentUser: boxSpace.currentUser.isCurrentUser,
            decorationID: restJourney.skinID
        )
    }

    // MARK: - LLM key management

    /// Store (or clear, if empty) the OpenRouter API key in the Keychain.
    func setAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Keychain.delete(Keys.apiKeyAccount)
            aiConfigured = false
        } else {
            Keychain.save(trimmed, for: Keys.apiKeyAccount)
            aiConfigured = true
        }
    }

    var hasAPIKey: Bool { Keychain.load(Keys.apiKeyAccount)?.isEmpty == false }

    func refreshBoxSpace() async {
        guard !communityRefreshInProgress else { return }
        communityRefreshInProgress = true
        boxSpaceLoading = true
        boxSpaceError = nil
        defer {
            boxSpaceLoading = false
            communityRefreshInProgress = false
        }
        do {
            async let mine = communityService.loadMyBoxSpace()
            async let ranking = communityService.loadMonthlyLeaderboard()
            let (myBox, leaderboard) = try await (mine, ranking)
            applyCommunitySnapshot(myBox, leaderboard: leaderboard)
        } catch {
            #if DEBUG
            debugPrint("Box Space sync failed:", error)
            #endif
            boxSpaceError = friendlyCommunityError(error)
        }
    }

    func selectBoxDecoration(_ decorationID: String) async {
        guard selectingSkinID == nil,
              let decoration = boxSpace.decorations.first(where: { $0.id == decorationID }),
              restJourney.points >= decoration.requiredScore else { return }
        let previous = restJourney.skinID
        selectingSkinID = decorationID
        restJourney.skinID = decorationID
        persistRestJourney()
        applyLocalJourneyToBoxSpace()
        defer { selectingSkinID = nil }

        do {
            let response = try await communityService.setMonthlySkin(id: decorationID)
            restJourney.skinID = response.skinId
            persistRestJourney()
            await refreshBoxSpace()
        } catch {
            restJourney.skinID = previous
            persistRestJourney()
            applyLocalJourneyToBoxSpace()
            boxSpaceError = friendlyCommunityError(error)
        }
    }

    func claimBlueBoxReward(id: String, cost: Int) -> Bool {
        guard cost > 0,
              restJourney.points >= cost,
              !claimedBlueBoxRewardIDs.contains(id) else { return false }
        restJourney.points -= cost
        claimedBlueBoxRewardIDs.insert(id)
        persistRestJourney()
        persistClaimedBlueBoxRewards()
        applyLocalJourneyToBoxSpace()
        return true
    }

    func completeWindDown() async {
        await claim(
            event: "wind_down_completed",
            sourceKey: Self.utc8DayKey(Date()))
        await refreshBoxSpace()
    }

    /// Refreshes the local, idempotent point ledger from real Apple Health
    /// movement and sleep data. Existing days are replaced, not incremented.
    func refreshRestJourney(health: HealthManager, nights suppliedNights: [NightSample]? = nil) async {
        guard health.authorized else { return }
        async let activity = health.fetchJourneyActivity()
        let nights: [NightSample]
        if let suppliedNights {
            nights = suppliedNights
        } else {
            nights = await health.fetchNights(daysBack: 45)
        }
        let activityDays = await activity
        recalculateRestJourney(activity: activityDays, nights: nights)
        await syncEligibleCommunityClaims(activity: activityDays, nights: nights)
        await refreshBoxSpace()
    }

    private var llmClient: LLMClient? {
        guard let key = Keychain.load(Keys.apiKeyAccount),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return LLMClient(apiKey: key, model: llmModel, baseURL: llmBaseURL)
    }

    /// Repopulate all data for the current mode.
    func refresh(health: HealthManager, calendar: CalendarService) async {
        switch mode {
        case .sample:
            applySample()
            await refreshRestJourney(health: health)
        case .live:
            isLoading = true
            async let fetchedNights = health.fetchNights()
            async let fetchedEnergyDay = health.fetchTodayEnergy()
            let (nights, energyDay) = await (fetchedNights, fetchedEnergyDay)
            recentHealthNights = nights
            todayEnergyDay = energyDay
            healthAuthorized = health.authorized
            liveHasData = !nights.isEmpty
            let latest = nights.last
            healthLastNightTST = latest?.tstMin
            lastNightHR = latest?.avgHRBpm
            lastNightHRV = latest?.hrvMs
            lastNightWristTempC = latest?.wristTempC
            let temps = nights.compactMap { $0.wristTempC }
            wristTempBaselineC = temps.count >= 3 ? (temps.reduce(0,+) / Double(temps.count) * 10).rounded() / 10 : nil
            let built = LiveDataBuilder.build(nights: nights,
                                              name: displayName, warmingMethod: warmingMethod)
            user = built.user
            sleepLogs = built.sleepLogs
            prescriptions = built.prescriptions
            cbtiLogs = built.cbtiLogs
            cbtiPrescriptions = built.cbtiPrescriptions
            regularity = SleepScience.report(logs: built.sleepLogs)
            pod = seed.pod        // pod is always sample
            await categorizeCalendar(calendar: calendar)
            await refreshRestJourney(health: health, nights: nights)
            isLoading = false
        }
    }

    /// A lightweight foreground refresh for the current-day energy timeline.
    /// It intentionally avoids reloading the rest of the app's data.
    func refreshTodayEnergy(health: HealthManager) async {
        guard mode == .live else { return }
        todayEnergyDay = await health.fetchTodayEnergy()
    }

    var todayRestPointDay: RestPointDay? {
        restJourney.dailyScores[Self.localDayKey(Date())]
    }

    var selectedBoxDecoration: BoxDecoration? {
        boxSpace.decorations.first { $0.id == restJourney.skinID }
            ?? boxSpace.decorations.first { $0.id == "classic-blue" }
    }

    var nextLockedDecoration: BoxDecoration? {
        boxSpace.decorations
            .filter { $0.requiredScore > restJourney.points }
            .min { $0.requiredScore < $1.requiredScore }
    }

    /// Live mode only: fetch raw calendar events and let the LLM categorize any
    /// that aren't already in the persistent cache (new or edited ones). Cached
    /// categorizations keep working with no key or a failed call — only the
    /// uncached events go missing until the next successful run.
    func categorizeCalendar(calendar: CalendarService) async {
        guard mode == .live else { return }
        aiError = nil
        aiConfigured = hasAPIKey
        let raw = await calendar.fetchRawEvents()
        let output = await CalendarCategorizer.categorize(
            rawEvents: raw, targetWake: user.targetWakeTime,
            client: llmClient, cache: loadCalendarCache(),
            overrides: loadCategoryOverrides(), healthContext: healthContextForAI())
        calendarEvents = output.result.events
        adaptations = output.result.adaptations
        baseAgenda = output.agenda
        applyAgenda()
        // Don't wipe the cache when the fetch itself came back empty (e.g. access
        // not yet granted) — those categorizations may still be valid next run.
        if !raw.isEmpty { saveCalendarCache(output.cache) }
        if let error = output.error {
            aiError = (error as? LLMError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Manually reclassify an event; persists and re-runs the (cache-hit) pass so
    /// the agenda updates without another LLM call. Pass nil to clear the override.
    func overrideEventCategory(eventId: String, category: String?, calendar: CalendarService) async {
        var overrides = loadCategoryOverrides()
        if let category { overrides[eventId] = category } else { overrides.removeValue(forKey: eventId) }
        UserDefaults.standard.set(overrides, forKey: Keys.calendarOverrides)
        await categorizeCalendar(calendar: calendar)
    }

    func categoryOverride(for eventId: String) -> String? { loadCategoryOverrides()[eventId] }

    func updateTonightPlan(_ plan: DayPlan, calendar: Calendar = .current) {
        if calendar.isDateInToday(plan.day) {
            tonightPlan = plan
        }
    }

    func clearTonightPlan(calendar: Calendar = .current) {
        guard let tonightPlan, calendar.isDateInToday(tonightPlan.day) else { return }
        self.tonightPlan = nil
    }

    /// Recompute the displayed agenda. Demo mode intentionally replaces the real
    /// agenda so illustrative events never overlap a user's actual calendar.
    private func applyAgenda() {
        agendaEvents = demoEventsEnabled ? Self.demoAgendaEvents() : baseAgenda
        tonightPlan = nil
    }

    /// Illustrative events anchored to today, spanning the categories, so the
    /// Agenda + plan + circadian view can be shown end-to-end without a calendar.
    static func demoAgendaEvents(now: Date = Date(), calendar: Calendar = .current) -> [AgendaEvent] {
        let d0 = calendar.startOfDay(for: now)
        func at(_ dayOffset: Int, _ h: Int, _ m: Int) -> Date {
            calendar.date(byAdding: .day, value: dayOffset, to: d0)
                .flatMap { calendar.date(bySettingHour: h, minute: m, second: 0, of: $0) } ?? now
        }
        return [
            AgendaEvent(id: "demo-morning-run", title: "Morning run", start: at(0, 6, 45), end: at(0, 7, 30),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-breakfast", title: "Breakfast + commute", start: at(0, 7, 45), end: at(0, 8, 45),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-focus", title: "Deep work block", start: at(0, 9, 0), end: at(0, 11, 0),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-standup", title: "Team stand-up", start: at(0, 10, 0), end: at(0, 10, 30),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-lunch", title: "Lunch with Sam", start: at(0, 12, 30), end: at(0, 13, 30),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-presentation-prep", title: "Presentation prep", start: at(0, 14, 0), end: at(0, 15, 30),
                        isAllDay: false, category: "demanding_event",
                        why: "A cognitively demanding block can raise evening arousal, so the plan protects a clean wind-down window."),
            AgendaEvent(id: "demo-milk-tea", title: "Milk tea catch-up", start: at(0, 16, 30), end: at(0, 17, 0),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-gym", title: "Strength training", start: at(0, 17, 45), end: at(0, 18, 45),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-dinner", title: "Hotpot dinner", start: at(0, 19, 30), end: at(0, 21, 0),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-night-out", title: "KTV with friends", start: at(0, 21, 30), end: at(1, 1, 15),
                        isAllDay: false, category: "social_jetlag",
                        why: "This runs well past your usual bedtime, pushing your sleep midpoint later and making sleeping in tempting tomorrow."),
            AgendaEvent(id: "demo-early-training", title: "7 AM training session", start: at(1, 7, 0), end: at(1, 8, 0),
                        isAllDay: false, category: "early_obligation",
                        why: "An early obligation after a late night compresses sleep opportunity, so EMBER shifts prep earlier and flags the risk."),
            AgendaEvent(id: "demo-board", title: "Board presentation", start: at(1, 10, 0), end: at(1, 11, 30),
                        isAllDay: false, category: "demanding_event",
                        why: "A high-stakes morning rewards solid sleep beforehand for memory, attention, and emotional control."),
            AgendaEvent(id: "demo-recovery-walk", title: "Recovery walk", start: at(1, 17, 30), end: at(1, 18, 15),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-family-dinner", title: "Family dinner", start: at(1, 19, 0), end: at(1, 20, 15),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-family-call", title: "Family video call", start: at(1, 20, 30), end: at(1, 21, 0),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-flight", title: "Flight SFO to London", start: at(2, 18, 0), end: at(3, 12, 0),
                        isAllDay: false, category: "timezone_travel",
                        why: "An overnight eastbound flight crosses time zones and benefits from a gradual phase advance beforehand."),
            AgendaEvent(id: "demo-hotel-checkin", title: "Hotel check-in", start: at(3, 13, 0), end: at(3, 14, 0),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-light-walk", title: "Bright-light walk", start: at(3, 16, 0), end: at(3, 16, 45),
                        isAllDay: false, category: "timezone_travel",
                        why: "Outdoor light at the destination helps anchor the shifted circadian schedule after travel."),
            AgendaEvent(id: "demo-client-dinner", title: "Client dinner", start: at(3, 20, 30), end: at(3, 22, 30),
                        isAllDay: false, category: "social_jetlag",
                        why: "A later dinner after travel can delay wind-down, so the plan keeps the next wake anchor visible."),
            AgendaEvent(id: "demo-yoga", title: "Hotel gym yoga", start: at(4, 7, 30), end: at(4, 8, 15),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-workshop", title: "All-day strategy workshop", start: at(4, 9, 0), end: at(4, 16, 30),
                        isAllDay: false, category: "demanding_event",
                        why: "A long cognitive day increases the value of a predictable bedtime and protected wind-down."),
            AgendaEvent(id: "demo-friends-drinks", title: "Night market with friends", start: at(4, 22, 0), end: at(5, 0, 30),
                        isAllDay: false, category: "social_jetlag",
                        why: "A late social plan shifts sleep timing later; EMBER highlights the tradeoff before it happens."),
            AgendaEvent(id: "demo-early-train", title: "Early high-speed train", start: at(5, 6, 40), end: at(5, 8, 0),
                        isAllDay: false, category: "early_obligation",
                        why: "An early departure pulls the practical wake time forward and reduces sleep opportunity."),
            AgendaEvent(id: "demo-swim", title: "Evening swim", start: at(5, 18, 30), end: at(5, 19, 15),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-brunch", title: "Weekend brunch", start: at(6, 11, 0), end: at(6, 12, 30),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-movie", title: "Late movie", start: at(6, 21, 45), end: at(7, 0, 10),
                        isAllDay: false, category: "social_jetlag",
                        why: "Late entertainment can push the sleep midpoint later, so the app keeps the next morning's wake anchor explicit."),
        ]
    }

    private func loadCategoryOverrides() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: Keys.calendarOverrides) as? [String: String] ?? [:]
    }

    /// A compact, number-free-safe summary of the user's recent sleep, given to
    /// the categorizer so each event's "why" can be personal.
    private func healthContextForAI() -> String {
        var parts = ["habitual bedtime \(user.targetBedTime), wake \(user.targetWakeTime)"]
        let tsts = sleepLogs.suffix(7).map { $0.tstMin }
        if !tsts.isEmpty { parts.append("average sleep over the last \(tsts.count) nights is \(fmtDur(tsts.reduce(0,+) / tsts.count))") }
        if let hrv = lastNightHRV { parts.append("last night's HRV was \(Int(hrv)) ms") }
        if let dev = wristTempDeviationC, abs(dev) >= 0.3 {
            parts.append("wrist temperature ran \(dev > 0 ? "+" : "")\(String(format: "%.1f", dev))°C vs baseline (a relative wrist skin measure, not core temperature — can rise with illness, alcohol, or menstrual phase)")
        }
        if let climate = sleepClimate, climate.risk != .low {
            let humidity = climate.maxHumidity.map { ", humidity up to \(Int(($0 * 100).rounded()))%" } ?? ""
            parts.append("tonight's local sleep climate is \(climate.risk.label.lowercased()): \(Int(climate.overnightLowC))-\(Int(climate.overnightHighC))°C\(humidity); use this only for sleep-friction advice, not as a circadian phase shift")
        }
        if let debt = sleepDebtMin(), debt >= 30 { parts.append("carrying roughly \(fmtDur(debt)) of sleep debt this week") }
        return parts.joined(separator: "; ") + "."
    }

    /// Rolling sleep debt: shortfall vs. the target nightly duration over recent nights.
    private func sleepDebtMin() -> Int? {
        let recent = sleepLogs.suffix(7)
        guard !recent.isEmpty else { return nil }
        let need = desiredNightlySleepMin()
        return recent.reduce(0) { $0 + max(0, need - $1.tstMin) }
    }

    /// Target sleep duration implied by the user's bed/wake times (wraps midnight).
    func desiredNightlySleepMin() -> Int {
        func mins(_ s: String) -> Int { let p = s.split(separator: ":").compactMap { Int($0) }; return p.count >= 2 ? p[0]*60+p[1] : 0 }
        return ((mins(user.targetWakeTime) - mins(user.targetBedTime)) % 1440 + 1440) % 1440
    }

    /// Invoked from the background app-refresh task: re-categorize the calendar
    /// (cache-aware, so a run without new events makes no LLM call) and let the
    /// wake alarm adapt to any newly discovered early obligation.
    func backgroundPlanRefresh(calendar: CalendarService, wakeAlarm: WakeAlarmService) async {
        guard mode == .live else { return }
        await categorizeCalendar(calendar: calendar)
        await wakeAlarm.autoAdapt(events: calendarEvents, adaptations: adaptations)
    }

    private func loadCalendarCache() -> [String: CalendarCategorizer.Categorization] {
        guard let data = UserDefaults.standard.data(forKey: Keys.calendarCache),
              let cache = try? JSONDecoder().decode([String: CalendarCategorizer.Categorization].self, from: data)
        else { return [:] }
        return cache
    }

    private func saveCalendarCache(_ cache: [String: CalendarCategorizer.Categorization]) {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: Keys.calendarCache)
        }
    }

    // MARK: - Local Rest Journey

    private static func loadRestJourney() -> RestJourneyProfile {
        guard let data = UserDefaults.standard.data(forKey: Keys.restJourney),
              let profile = try? JSONDecoder().decode(RestJourneyProfile.self, from: data)
        else { return .empty }
        return profile
    }

    private func persistRestJourney() {
        guard let data = try? JSONEncoder().encode(restJourney) else { return }
        UserDefaults.standard.set(data, forKey: Keys.restJourney)
    }

    private func persistClaimedBlueBoxRewards() {
        UserDefaults.standard.set(Array(claimedBlueBoxRewardIDs).sorted(), forKey: Keys.blueBoxRewards)
    }

    private func applyLocalJourneyToBoxSpace() {
        boxSpace.currentUser = BoxSpacePerson(
            id: boxSpace.currentUser.id,
            name: displayName,
            monthlyScore: restJourney.points,
            rank: boxSpace.currentUser.rank,
            isFriend: boxSpace.currentUser.isFriend,
            isCurrentUser: boxSpace.currentUser.isCurrentUser,
            decorationID: restJourney.skinID)
    }

    private func recalculateRestJourney(
        activity: [JourneyActivityDay],
        nights: [NightSample]
    ) {
        let activityByDay = Dictionary(uniqueKeysWithValues: activity.map {
            (Self.localDayKey($0.date), $0)
        })
        let sleepByDay = Dictionary(
            nights.map { ($0.date, $0.tstMin) },
            uniquingKeysWith: { _, newest in newest })
        let affectedDays = Set(activityByDay.keys).union(sleepByDay.keys)

        for day in affectedDays {
            let movement = activityByDay[day]
            let score = Self.makeRestPointDay(
                id: day,
                steps: Int((movement?.steps ?? 0).rounded()),
                activeEnergyKcal: Int((movement?.activeEnergyKcal ?? 0).rounded()),
                exerciseMinutes: Int((movement?.exerciseMinutes ?? 0).rounded()),
                sleepMinutes: sleepByDay[day])
            restJourney.dailyScores[day] = score
        }
        persistRestJourney()
        applyLocalJourneyToBoxSpace()
    }

    private func applyCommunitySnapshot(
        _ myBox: MyBoxSpaceRecord,
        leaderboard: [MonthlyLeaderboardRecord]
    ) {
        restJourney.points = myBox.points
        restJourney.skinID = myBox.skinId
        persistRestJourney()

        let friends = leaderboard
            .filter { !$0.isCurrentUser }
            .map {
                BoxSpacePerson(
                    id: $0.userId.uuidString,
                    name: $0.displayName,
                    monthlyScore: $0.points,
                    rank: $0.rankNumber,
                    isFriend: true,
                    isCurrentUser: false,
                    decorationID: $0.skinId)
            }
        boxSpace = BoxSpaceSnapshot(
            monthLabel: Self.monthLabel(myBox.monthStart),
            resetsAt: myBox.resetsAt,
            currentUser: BoxSpacePerson(
                id: myBox.userId.uuidString,
                name: myBox.displayName,
                monthlyScore: myBox.points,
                rank: myBox.rankNumber,
                isFriend: true,
                isCurrentUser: true,
                decorationID: myBox.skinId),
            people: friends + [
                BoxSpacePerson(
                    id: "empty-box-\(myBox.monthStart)", name: "", monthlyScore: 0, rank: 0,
                    isFriend: false, isCurrentUser: false, decorationID: nil)
            ],
            decorations: BoxSpaceSnapshot.localDecorations)
        applyAuthenticatedDisplayName(myBox.displayName)
    }

    private func syncEligibleCommunityClaims(
        activity: [JourneyActivityDay],
        nights: [NightSample]
    ) async {
        let today = Self.utc8DayKey(Date())
        if !activity.isEmpty || !nights.isEmpty {
            await claim(event: "daily_check_in", sourceKey: today)
        }

        guard let latest = nights.last else { return }
        if latest.tstMin >= 420, latest.sePct >= 80 {
            await claim(event: "rested_well", sourceKey: latest.date)
        }
        if nights.count >= 3,
           let deviation = regularity.midpointStdevMin,
           deviation <= 45 {
            await claim(event: "rhythm_kept", sourceKey: latest.date)
        }

        let consecutive = Self.currentSleepStreak(nights)
        if consecutive >= 10 {
            await claim(event: "ten_days_rest", sourceKey: "milestone:ten_days_rest")
        }
        if consecutive >= 7,
           let deviation = regularity.midpointStdevMin,
           deviation <= 45 {
            await claim(event: "rhythm_keeper", sourceKey: "milestone:rhythm_keeper")
        }
    }

    private func claim(event: String, sourceKey: String) async {
        do {
            let response = try await communityService.awardPoints(
                eventType: event,
                sourceKey: sourceKey)
            if response.status == "awarded" || response.status == "duplicate" {
                completedPointEvents.insert(event)
                restJourney.points = response.points
                restJourney.skinID = response.skinId
                persistRestJourney()
                applyLocalJourneyToBoxSpace()
            }
        } catch {
            #if DEBUG
            debugPrint("Point claim failed:", event, error)
            #endif
        }
    }

    private static func currentSleepStreak(_ nights: [NightSample]) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = Set(nights.filter { $0.tstMin >= 300 }.compactMap { formatter.date(from: $0.date) })
            .sorted()
        guard let latest = dates.last else { return 0 }
        let age = calendar.dateComponents(
            [.day], from: latest, to: calendar.startOfDay(for: Date())).day ?? 99
        guard age <= 1 else { return 0 }
        var streak = 1
        var cursor = latest
        while let previous = calendar.date(byAdding: .day, value: -1, to: cursor),
              dates.contains(previous) {
            streak += 1
            cursor = previous
        }
        return streak
    }

    private static func utc8DayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func monthLabel(_ monthStart: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: monthStart) else { return "" }
        return date.formatted(.dateTime.month(.wide))
    }

    private func friendlyCommunityError(_ error: Error) -> String {
        let text = error.localizedDescription.lowercased()
        if text.contains("jwt") || text.contains("session") || text.contains("unauthorized") {
            return "Your session has expired. Please sign in again."
        }
        if text.contains("network") || text.contains("internet") || text.contains("offline") {
            return "Box Space could not sync. Check your connection and try again."
        }
        if text.contains("function") && text.contains("not found") {
            return "Box Space is not available on this server version."
        }
        return "Box Space could not sync right now."
    }

    private static func makeRestPointDay(
        id: String,
        steps: Int,
        activeEnergyKcal: Int,
        exerciseMinutes: Int,
        sleepMinutes: Int?
    ) -> RestPointDay {
        // Max 100/day. Integer bands keep the score stable as HealthKit samples
        // trickle in and make every awarded point easy to explain.
        let stepPoints = min(30, max(0, steps / 1_000 * 3))
        let energyPoints = min(20, max(0, activeEnergyKcal / 50 * 2))
        let exercisePoints = min(20, max(0, exerciseMinutes / 10 * 5))
        let sleepPoints: Int
        switch sleepMinutes ?? 0 {
        case 420...: sleepPoints = 30
        case 360..<420: sleepPoints = 20
        case 300..<360: sleepPoints = 10
        default: sleepPoints = 0
        }

        let sleepDetail = sleepMinutes.map {
            let hours = $0 / 60
            let minutes = $0 % 60
            return minutes == 0 ? "\(hours)h from Apple Health" : "\(hours)h \(minutes)m from Apple Health"
        } ?? "No sleep record yet"
        return RestPointDay(
            id: id,
            steps: steps,
            activeEnergyKcal: activeEnergyKcal,
            exerciseMinutes: exerciseMinutes,
            sleepMinutes: sleepMinutes,
            components: [
                RestPointComponent(
                    id: "sleep", title: "Rested sleep", detail: sleepDetail,
                    points: sleepPoints, maximumPoints: 30),
                RestPointComponent(
                    id: "steps", title: "Daily steps", detail: "\(steps.formatted()) steps",
                    points: stepPoints, maximumPoints: 30),
                RestPointComponent(
                    id: "active_energy", title: "Active energy",
                    detail: "\(activeEnergyKcal.formatted()) active kcal",
                    points: energyPoints, maximumPoints: 20),
                RestPointComponent(
                    id: "exercise", title: "Exercise time",
                    detail: "\(exerciseMinutes.formatted()) Apple Exercise min",
                    points: exercisePoints, maximumPoints: 20)
            ])
    }

    private static func localDayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Streaming coach reply: appends an empty coach message and fills it token by
    /// token. Falls back to the rule-based coach when no key is set or the stream
    /// fails before producing any text. `history` ends with the user's message.
    func streamCoachReply(history: [ChatMessage]) async {
        let lastUser = history.last(where: { $0.role == .user })?.content ?? ""
        guard let client = llmClient else {
            let reply = await RestCoach.answer(to: lastUser, store: self, adaptations: adaptations)
            chat.append(ChatMessage(role: .coach, content: reply))
            return
        }
        let system = RestCoach.systemPrompt + "\n\nCURRENT USER DATA:\n" + RestCoach.contextSnapshot(store: self)
        var turns = history.suffix(12).map {
            LLMClient.ChatTurn(role: $0.role == .user ? "user" : "assistant", content: $0.content)
        }
        while turns.first?.role == "assistant" { turns.removeFirst() }

        chat.append(ChatMessage(role: .coach, content: ""))
        let id = chat.last!.id
        func setContent(_ text: String) { if let i = chat.firstIndex(where: { $0.id == id }) { chat[i].content = text } }
        func appendContent(_ text: String) { if let i = chat.firstIndex(where: { $0.id == id }) { chat[i].content += text } }

        do {
            for try await piece in client.chatStream(system: system, messages: turns) {
                appendContent(piece)
            }
            if let i = chat.firstIndex(where: { $0.id == id }), chat[i].content.isEmpty {
                setContent(await RestCoach.answer(to: lastUser, store: self, adaptations: adaptations))
            }
        } catch {
            let produced = chat.first(where: { $0.id == id })?.content ?? ""
            if produced.isEmpty {
                setContent(await RestCoach.answer(to: lastUser, store: self, adaptations: adaptations))
            }
        }
    }

    func sendMindDumpMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mindChat.append(ChatMessage(role: .user, content: trimmed))
        updateMindReminderItems(from: trimmed)
        persistMindChat()
        await scheduleMindDumpReminder()
        await streamMindDumpReply(history: mindChat)
    }

    func resetMindDump() {
        mindChat = [Self.mindDumpOpeningMessage]
        mindReminderItems = []
        persistMindChat()
        persistMindReminderItems()
    }

    private func updateMindReminderItems(from text: String) {
        let extracted = Self.extractMindReminderItems(from: text)
        guard !extracted.isEmpty else { return }
        var merged = mindReminderItems
        for item in extracted where !merged.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
            merged.append(item)
        }
        mindReminderItems = Array(merged.suffix(4))
        persistMindReminderItems()
    }

    private func streamMindDumpReply(history: [ChatMessage]) async {
        let lastUser = history.last(where: { $0.role == .user })?.content ?? ""
        let fallback = Self.mindDumpFallback(for: lastUser)
        guard let client = llmClient else {
            mindChat.append(ChatMessage(role: .coach, content: fallback))
            persistMindChat()
            return
        }

        let system = """
        You are EMBER's short evening brain-dump coach. Help the user lower pre-sleep anxiety by externalizing worries, separating controllable next actions from parked thoughts, and ending with one tiny next step.
        Keep replies under 70 words. Use warm, plain language. Do not diagnose, do not claim therapy, and do not over-medicalize. If the user describes immediate danger or intent to harm themselves or someone else, tell them to contact local emergency services now.
        """
        var turns = history.suffix(12).map {
            LLMClient.ChatTurn(role: $0.role == .user ? "user" : "assistant", content: $0.content)
        }
        while turns.first?.role == "assistant" { turns.removeFirst() }

        mindChat.append(ChatMessage(role: .coach, content: ""))
        let id = mindChat.last!.id
        func setContent(_ text: String) { if let i = mindChat.firstIndex(where: { $0.id == id }) { mindChat[i].content = text } }
        func appendContent(_ text: String) { if let i = mindChat.firstIndex(where: { $0.id == id }) { mindChat[i].content += text } }

        do {
            for try await piece in client.chatStream(system: system, messages: turns) {
                appendContent(piece)
            }
            if let i = mindChat.firstIndex(where: { $0.id == id }), mindChat[i].content.isEmpty {
                setContent(fallback)
            }
        } catch {
            let produced = mindChat.first(where: { $0.id == id })?.content ?? ""
            if produced.isEmpty {
                setContent(fallback)
            }
        }
        persistMindChat()
    }

    private func scheduleMindDumpReminder() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        let latestSettings = await center.notificationSettings()
        guard latestSettings.authorizationStatus == .authorized
            || latestSettings.authorizationStatus == .provisional else { return }

        center.removePendingNotificationRequests(withIdentifiers: [Keys.mindReminder])
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 30

        let content = UNMutableNotificationContent()
        content.title = "Revisit last night's brain dump"
        if mindReminderItems.isEmpty {
            content.body = "Take one minute to sort what still needs action and what can stay parked."
        } else {
            content.body = "Check: " + mindReminderItems.prefix(2).joined(separator: " · ")
        }
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Keys.mindReminder,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        try? await center.add(request)
    }

    private func persistMindChat() {
        let payload = mindChat.map {
            PersistedChatMessage(role: $0.role == .user ? "user" : "coach", content: $0.content)
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: Keys.mindChat)
    }

    private func persistMindReminderItems() {
        UserDefaults.standard.set(mindReminderItems, forKey: Keys.mindReminderItems)
    }

    private static func loadMindChat() -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: Keys.mindChat),
              let payload = try? JSONDecoder().decode([PersistedChatMessage].self, from: data) else { return [] }
        return payload.compactMap { item in
            let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return nil }
            return ChatMessage(role: item.role == "user" ? .user : .coach, content: content)
        }
    }

    private static func loadMindReminderItems() -> [String] {
        UserDefaults.standard.stringArray(forKey: Keys.mindReminderItems) ?? []
    }

    private static var mindDumpOpeningMessage: ChatMessage {
        ChatMessage(
            role: .coach,
            content: "Tell me what's on your mind. Brain dump everything here; I'll help park it for tonight and remind you tomorrow.")
    }

    private static func mindDumpFallback(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("anxious") || lower.contains("worry") || lower.contains("worried") || lower.contains("can't sleep") || lower.contains("cant sleep") {
            return "Got it. Put the worry outside your head for now: one thing you can do tomorrow, one thing that can wait, then let the rest stay parked here."
        }
        return "I saved it for tomorrow. For tonight, choose one tiny next action if there is one; everything else can stay in this dump until morning."
    }

    private static func extractMindReminderItems(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "\n.!?;")
        let actionHints = ["need to", "have to", "must", "should", "remember", "remind", "call", "email", "text", "send", "finish", "book", "pay", "buy", "ask", "reply", "prepare"]

        let items = text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { raw -> String? in
                let lower = raw.lowercased()
                guard actionHints.contains(where: { lower.contains($0) }) else { return nil }
                let cleaned = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                guard cleaned.count >= 6 else { return nil }
                return String(cleaned.prefix(80))
            }
        return Array(items.prefix(3))
    }

    private struct PersistedChatMessage: Codable {
        let role: String
        let content: String
    }

    private func applySample() {
        user = seed.user
        user.name = displayName
        sleepLogs = seed.sleepLogs
        prescriptions = seed.prescriptions
        cbtiLogs = seed.cbtiLogs
        cbtiPrescriptions = seed.cbtiPrescriptions
        calendarEvents = seed.calendarEvents
        adaptations = seed.adaptations
        baseAgenda = seed.calendarEvents.compactMap { e in
            guard let s = Self.parseSeedTs(e.startTs), let en = Self.parseSeedTs(e.endTs) else { return nil }
            return AgendaEvent(id: e.id, title: e.title, start: s, end: en, isAllDay: false,
                               category: RestAlgorithms.normalizedCategory(e.type),
                               why: seed.adaptations.first { $0.eventId == e.id }?.whyItAffectsSleep)
        }
        applyAgenda()
        regularity = SleepScience.report(logs: seed.sleepLogs)
        pod = seed.pod
        liveHasData = false
        recentHealthNights = Self.sampleHealthNights(from: seed.sleepLogs)
        todayEnergyDay = Self.sampleEnergyDay(from: recentHealthNights)
        let latest = recentHealthNights.last
        healthLastNightTST = latest?.tstMin
        lastNightHR = latest?.avgHRBpm
        lastNightHRV = latest?.hrvMs
        lastNightWristTempC = latest?.wristTempC
        let temps = recentHealthNights.compactMap(\.wristTempC)
        wristTempBaselineC = temps.count >= 3 ? (temps.reduce(0,+) / Double(temps.count) * 10).rounded() / 10 : nil
        aiError = nil
    }

    private static func sampleHealthNights(from logs: [SleepLog], calendar: Calendar = .current) -> [NightSample] {
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.timeZone = calendar.timeZone
        dayFormatter.dateFormat = "yyyy-MM-dd"

        return logs.enumerated().compactMap { index, log in
            guard let wakeDay = dayFormatter.date(from: log.date),
                  let lightsOut = sampleDate(day: wakeDay, hhmm: log.lightsOut, wrapsToPreviousDay: true, calendar: calendar),
                  let wake = sampleDate(day: wakeDay, hhmm: log.wakeTime, wrapsToPreviousDay: false, calendar: calendar)
            else { return nil }

            let onset = lightsOut.addingTimeInterval((log.solMin ?? 0) * 60)
            let tibMin = max(1, Int(wake.timeIntervalSince(lightsOut) / 60))
            let wasoMin = max(0, tibMin - Int((log.solMin ?? 0).rounded()) - log.tstMin)
            let hrv = 51 + Double((index * 7) % 13) - max(0, (log.solMin ?? 0) - 20) * 0.16
            let hr = 58 + Double((index * 5) % 7) + Double(wasoMin) * 0.03
            let wrist = 36.35 + Double((index % 5) - 2) * 0.06

            return NightSample(
                date: log.date,
                lightsOut: lightsOut,
                sleepOnset: onset,
                finalWake: wake,
                solMin: log.solMin ?? 0,
                tstMin: log.tstMin,
                wasoMin: wasoMin,
                tibMin: tibMin,
                sePct: (Double(log.tstMin) / Double(tibMin) * 100).rounded(toPlaces: 1),
                timeZone: calendar.timeZone,
                avgHRBpm: hr.rounded(),
                hrvMs: max(30, hrv).rounded(),
                wristTempC: (wrist * 10).rounded() / 10)
        }
    }

    private static func sampleDate(day: Date, hhmm: String, wrapsToPreviousDay: Bool, calendar: Calendar) -> Date? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        let baseDay = wrapsToPreviousDay && parts[0] >= 12
            ? calendar.date(byAdding: .day, value: -1, to: day) ?? day
            : day
        return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: baseDay)
    }

    private static func sampleEnergyDay(from nights: [NightSample], calendar: Calendar = .current) -> DailyEnergyDay? {
        guard let latest = nights.last else { return nil }
        let start = calendar.startOfDay(for: Date())
        let hour = calendar.component(.hour, from: Date())
        let buckets = (0...max(hour, 8)).compactMap { offset -> DailyEnergyInput? in
            guard let time = calendar.date(byAdding: .hour, value: offset, to: start) else { return nil }
            let asleep = offset < 6 ? 52.0 : 0
            let commuteLoad = offset == 8 ? 260.0 : 0
            let workoutLoad = offset == 17 ? 620.0 : 0
            let steps = asleep > 0 ? 0 : 70 + Double((offset * 83) % 420) + commuteLoad + workoutLoad
            let active = asleep > 0 ? 0 : 2 + Double((offset * 5) % 22) + workoutLoad / 55
            let hr = asleep > 0 ? 56 + Double(offset % 2) : 63 + Double((offset * 3) % 14) + workoutLoad / 160
            let hrv = asleep > 0 ? latest.hrvMs.map { $0 + 4 } : latest.hrvMs.map { max(30, $0 - Double(offset % 5)) }
            return DailyEnergyInput(
                time: time,
                averageHeartRate: hr,
                averageHRV: hrv,
                activeEnergyKcal: active,
                steps: steps,
                asleepMinutes: asleep)
        }
        let hrvBaseline = median(nights.compactMap(\.hrvMs))
        let hrBaseline = median(nights.compactMap(\.avgHRBpm))
        return DailyEnergyDay(buckets: buckets, restingHeartRateBaseline: hrBaseline, hrvBaseline: hrvBaseline)
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// Last night's sleeping wrist temperature relative to the recent baseline
    /// (°C). Relative only — wrist skin, not core; nil until a baseline exists.
    var wristTempDeviationC: Double? {
        guard let last = lastNightWristTempC, let base = wristTempBaselineC else { return nil }
        return ((last - base) * 10).rounded() / 10
    }

    // Derived: current thermal prescription (latest block)
    var currentThermalRx: ThermalPrescription? { prescriptions.max(by: { $0.block < $1.block }) }
    // Derived: current CBT-I prescription (latest week)
    var currentCBTIRx: CBTIPrescription? { cbtiPrescriptions.max(by: { $0.week < $1.week }) }

    var thermalConverged: Bool { currentThermalRx?.converged ?? false }
}
