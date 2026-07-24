import Foundation

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
    @Published var boxSpaceLoading = false
    @Published var boxSpaceError: String? = nil
    @Published var chat: [ChatMessage] = []
    /// Set by other screens ("Ask the coach") so CoachView can auto-send on appear.
    @Published var pendingCoachQuestion: String? = nil

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
        boxSpace = .sample
        chat = [ChatMessage(role: .coach,
            content: "Hi \(displayName) — I'm your rest coach. Ask me why any prescription changed, or tap a suggested question below.")]
        if mode == .sample { applySample() }
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
            monthlyScore: boxSpace.currentUser.monthlyScore,
            rank: boxSpace.currentUser.rank,
            isFriend: boxSpace.currentUser.isFriend,
            isCurrentUser: boxSpace.currentUser.isCurrentUser,
            decorationID: boxSpace.currentUser.decorationID
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
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "BOX_SPACE_API_URL") as? String,
              let url = URL(string: rawURL), !rawURL.isEmpty else { return }
        boxSpaceLoading = true
        boxSpaceError = nil
        defer { boxSpaceLoading = false }
        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            boxSpace = try JSONDecoder().decode(BoxSpaceSnapshot.self, from: data)
            applyAuthenticatedDisplayName(displayName)
        } catch {
            boxSpaceError = error.localizedDescription
        }
    }

    func selectBoxDecoration(_ decorationID: String?) {
        if let decorationID {
            guard let decoration = boxSpace.decorations.first(where: { $0.id == decorationID }),
                  boxSpace.currentUser.monthlyScore >= decoration.requiredScore else { return }
        }
        boxSpace.currentUser.decorationID = decorationID
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
        case .live:
            isLoading = true
            let nights = await health.fetchNights()
            let energyDay = await health.fetchTodayEnergy()
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
            isLoading = false
        }
    }

    /// A lightweight foreground refresh for the current-day energy timeline.
    /// It intentionally avoids reloading the rest of the app's data.
    func refreshTodayEnergy(health: HealthManager) async {
        guard mode == .live else { return }
        todayEnergyDay = await health.fetchTodayEnergy()
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

    /// Recompute the displayed agenda from the real events plus (optionally) the
    /// demo set. Demo events are always re-anchored to the current date.
    private func applyAgenda() {
        agendaEvents = baseAgenda + (demoEventsEnabled ? Self.demoAgendaEvents() : [])
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
            AgendaEvent(id: "demo-lunch", title: "Lunch with Sam", start: at(0, 12, 30), end: at(0, 13, 30),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-concert", title: "Live show at The Warehouse", start: at(0, 21, 0), end: at(1, 0, 30),
                        isAllDay: false, category: "social_jetlag",
                        why: "This runs past midnight, pushing your sleep midpoint later — sleeping in to recover would create social jet lag."),
            AgendaEvent(id: "demo-flight", title: "Flight SFO → London", start: at(2, 18, 0), end: at(3, 12, 0),
                        isAllDay: false, category: "timezone_travel",
                        why: "An overnight eastbound flight crosses time zones and needs a gradual phase advance beforehand."),
            AgendaEvent(id: "demo-standup", title: "Team stand-up", start: at(1, 9, 0), end: at(1, 9, 30),
                        isAllDay: false, category: "neutral"),
            AgendaEvent(id: "demo-pitch", title: "Investor pitch", start: at(1, 7, 30), end: at(1, 8, 30),
                        isAllDay: false, category: "early_obligation",
                        why: "An early start truncates your sleep opportunity, so tonight's plan shifts earlier to protect a full night."),
            AgendaEvent(id: "demo-exam", title: "Board presentation", start: at(4, 10, 0), end: at(4, 11, 30),
                        isAllDay: false, category: "demanding_event",
                        why: "A high-stakes morning rewards solid sleep beforehand for memory and focus."),
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
        healthLastNightTST = nil
        lastNightHR = nil
        lastNightHRV = nil
        lastNightWristTempC = nil
        wristTempBaselineC = nil
        recentHealthNights = []
        todayEnergyDay = nil
        aiError = nil
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
