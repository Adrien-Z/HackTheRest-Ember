import Foundation

/// Where the app's data comes from.
enum DataSourceMode: String {
    case sample   // bundled seed.json — demo content so the app is never empty
    case live     // derived from Apple Health (+ EventKit) on this device
}

/// Central observable store. Holds either the bundled sample data or live data
/// derived from Apple Health / EventKit, chosen by an explicit mode toggle in
/// Settings (no automatic fallback). The Pod is social data with no on-device
/// source, so it always shows sample content.
@MainActor
final class DataStore: ObservableObject {
    @Published var user: UserProfile
    @Published var sleepLogs: [SleepLog] = []
    @Published var prescriptions: [ThermalPrescription] = []
    @Published var cbtiLogs: [CBTILog] = []
    @Published var cbtiPrescriptions: [CBTIPrescription] = []
    @Published var calendarEvents: [CalendarEvent] = []
    @Published var adaptations: [Adaptation] = []
    @Published var pod: Pod                    // always sample data
    @Published var chat: [ChatMessage] = []
    /// Set by other screens ("Ask the coach") so CoachView can auto-send on appear.
    @Published var pendingCoachQuestion: String? = nil

    // Live Apple Health readout (nil until authorized + fetched)
    @Published var healthLastNightTST: Int? = nil
    @Published var lastNightHR: Double? = nil     // mean overnight heart rate (bpm)
    @Published var lastNightHRV: Double? = nil    // mean overnight HRV SDNN (ms)
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
        aiConfigured = Keychain.load(Keys.apiKeyAccount)?.isEmpty == false
        user = bundleSeed.user
        pod = bundleSeed.pod
        chat = [ChatMessage(role: .coach,
            content: "Hi \(bundleSeed.user.name) — I'm your rest coach. Ask me why any prescription changed, or tap a suggested question below.")]
        if mode == .sample { applySample() }
    }

    /// Sample data may still be missing from the bundle in unusual build setups;
    /// return empty defaults rather than crashing so live mode remains usable.
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
            healthAuthorized = health.authorized
            liveHasData = !nights.isEmpty
            let latest = nights.last
            healthLastNightTST = latest?.tstMin
            lastNightHR = latest?.avgHRBpm
            lastNightHRV = latest?.hrvMs
            let built = LiveDataBuilder.build(nights: nights,
                                              name: displayName, warmingMethod: warmingMethod)
            user = built.user
            sleepLogs = built.sleepLogs
            prescriptions = built.prescriptions
            cbtiLogs = built.cbtiLogs
            cbtiPrescriptions = built.cbtiPrescriptions
            pod = seed.pod        // pod is always sample
            await categorizeCalendar(calendar: calendar)
            isLoading = false
        }
    }

    /// Live mode only: fetch raw calendar events and let the LLM categorize them.
    /// No key or a failed call → no adaptations + a prompt (no keyword fallback).
    func categorizeCalendar(calendar: CalendarService) async {
        guard mode == .live else { return }
        aiError = nil
        aiConfigured = hasAPIKey
        let raw = await calendar.fetchRawEvents()
        guard let client = llmClient else {
            calendarEvents = []
            adaptations = []
            return
        }
        do {
            let result = try await CalendarCategorizer.categorize(
                rawEvents: raw, targetWake: user.targetWakeTime, client: client)
            calendarEvents = result.events
            adaptations = result.adaptations
        } catch {
            aiError = (error as? LLMError)?.errorDescription ?? error.localizedDescription
            calendarEvents = []
            adaptations = []
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
        sleepLogs = seed.sleepLogs
        prescriptions = seed.prescriptions
        cbtiLogs = seed.cbtiLogs
        cbtiPrescriptions = seed.cbtiPrescriptions
        calendarEvents = seed.calendarEvents
        adaptations = seed.adaptations
        pod = seed.pod
        liveHasData = false
        healthLastNightTST = nil
        lastNightHR = nil
        lastNightHRV = nil
        aiError = nil
    }

    // Derived: current thermal prescription (latest block)
    var currentThermalRx: ThermalPrescription? { prescriptions.max(by: { $0.block < $1.block }) }
    // Derived: current CBT-I prescription (latest week)
    var currentCBTIRx: CBTIPrescription? { cbtiPrescriptions.max(by: { $0.week < $1.week }) }

    var thermalConverged: Bool { currentThermalRx?.converged ?? false }
}
