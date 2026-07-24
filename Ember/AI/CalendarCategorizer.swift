import Foundation

/// Uses an LLM to categorize raw calendar events into sleep-relevant classes,
/// then maps each to a `CalendarEvent` + `Adaptation`. The model does the fuzzy
/// natural-language understanding (which category, travel direction, timezone
/// shift, a personalized "why"); the authoritative recommendation and citation
/// come from the pure, testable `RestAlgorithms.adapt` so the science can't be
/// fabricated.
enum CalendarCategorizer {

    struct Result {
        let events: [CalendarEvent]
        let adaptations: [Adaptation]
    }

    /// One cached LLM categorization, keyed by event id. The fingerprint detects
    /// edits (time/title/location changes) that invalidate the cached result, so
    /// only new or changed events are ever sent to the model. Neutral events are
    /// cached too — that's what marks them as "already seen".
    struct Categorization: Codable, Equatable {
        let fingerprint: String
        let category: String
        let direction: String?
        let tzOffsetHours: Int?
        let why: String?
    }

    struct Output {
        let result: Result
        /// Updated cache to persist; contains only ids still in the fetch window.
        let cache: [String: Categorization]
        /// LLM failure while categorizing NEW events (cached ones still applied).
        let error: Error?
    }

    // MARK: - Public entry point

    static func categorize(rawEvents: [RawCalendarEvent],
                           targetWake: String,
                           client: LLMClient?,
                           cache: [String: Categorization],
                           now: Date = Date()) async -> Output {
        // EventKit can occasionally return the same logical event more than once
        // (for example, a subscribed Zoom calendar mirrored into another source).
        // All downstream state is keyed by id, so collapse duplicates up front.
        let uniqueEvents = deduplicated(rawEvents)

        // Reuse cached categorizations for unchanged events; collect the rest.
        var merged: [String: Categorization] = [:]
        var pending: [RawCalendarEvent] = []
        for e in uniqueEvents {
            if let c = cache[e.id], c.fingerprint == fingerprint(of: e) {
                merged[e.id] = c
            } else {
                pending.append(e)
            }
        }

        var error: Error? = nil
        if !pending.isEmpty, let client {
            do {
                let raw = try await client.complete(system: systemPrompt, user: userPrompt(for: pending))
                for (id, c) in parse(jsonString: raw, rawEvents: pending) { merged[id] = c }
            } catch let e { error = e }
        }

        let result = buildResult(rawEvents: uniqueEvents, categorizations: merged,
                                 targetWake: targetWake, now: now)
        return Output(result: result, cache: merged, error: error)
    }

    /// Preserves the first occurrence from EventKit's start-time-sorted result.
    /// This is deterministic and prevents duplicate ids from reaching prompts,
    /// dictionaries, the cache, or the displayed adaptation list.
    static func deduplicated(_ events: [RawCalendarEvent]) -> [RawCalendarEvent] {
        var seen = Set<String>()
        return events.filter { seen.insert($0.id).inserted }
    }

    static func fingerprint(of e: RawCalendarEvent) -> String {
        "\(e.title)|\(e.start.timeIntervalSince1970)|\(e.end.timeIntervalSince1970)|\(e.isAllDay)|\(e.location ?? "")"
    }

    // MARK: - Prompt

    /// The science corpus + category definitions + output contract. The model is
    /// told to ground its "why" only in these facts (no invented citations).
    static let systemPrompt = """
    You are a sleep-medicine assistant that classifies calendar events by how they \
    affect circadian rhythm and sleep. For each event, choose exactly one category:

    - "timezone_travel": flights/trains that cross time zones. Also set "direction" \
      ("east" or "west" relative to the traveler) and "tzOffsetHours" (integer number \
      of time zones crossed). Eastward = phase advance (harder, ~1 zone/day); westward \
      = phase delay (easier, ~1.5 zones/day).
    - "social_jetlag": social events (concerts, parties, dinners, nights out) that run \
      into late-night hours and would push the sleep midpoint later. Sleeping in to \
      recover causes 'social jetlag' — misalignment of biological vs social time \
      (Wittmann & Roenneberg 2006), linked to metabolic and cardiovascular risk.
    - "early_obligation": meetings, flights, or appointments starting earlier than a \
      typical wake time, which truncate the sleep opportunity (Chaput 2020).
    - "demanding_event": high-stakes events (interviews, exams, major presentations) \
      where sleep the night before protects performance and memory (Windred 2024).
    - "neutral": no meaningful sleep impact.

    Rules:
    - Use the event's title, time, duration, location and notes to decide.
    - Only classify as travel if it genuinely crosses time zones; a local commute is neutral.
    - All-day events (allDay=true) span whole days; they carry NO meaningful clock time, so \
      never classify them by start/end hour. Birthdays, holidays, reminders and deadlines are \
      "neutral" unless the title or notes clearly imply timezone travel or a high-stakes \
      demanding event.
    - "why" must be one or two plain-language sentences explaining, for THIS event, why it \
      affects the user's sleep, using ONLY the mechanisms above. Do not invent studies or numbers.

    Respond with a single JSON object and nothing else:
    {"events":[{"id":"<echo the event id>","category":"<one of the categories>",\
    "direction":"east|west|null","tzOffsetHours":<integer or null>,"why":"<explanation>"}]}
    Include every input event exactly once.
    """

    private static func userPrompt(for events: [RawCalendarEvent]) -> String {
        let cal = Calendar.current
        let iso = ISO8601DateFormatter()
        var lines: [String] = ["Today is \(iso.string(from: Date())). Classify these events:"]
        for e in events {
            var fields = ["id=\(e.id)", "title=\(e.title)"]
            if e.isAllDay {
                // All-day events have placeholder midnight times — present dates only
                // so the model can't misread 00:00 as a late night or early start.
                let day = ymdFormatter
                fields.append("startDate=\(day.string(from: e.start))")
                fields.append("endDate=\(day.string(from: e.end))")
                fields.append("allDay=true")
            } else {
                let startHour = cal.component(.hour, from: e.start)
                let endHour = cal.component(.hour, from: e.end)
                let hours = e.end.timeIntervalSince(e.start) / 3600
                fields.append(contentsOf: [
                    "start=\(iso.string(from: e.start)) (local hour \(startHour))",
                    "end=\(iso.string(from: e.end)) (local hour \(endHour))",
                    "durationHours=\(String(format: "%.1f", hours))",
                    "allDay=false"
                ])
            }
            if let loc = e.location, !loc.isEmpty { fields.append("location=\(loc)") }
            if let notes = e.notes, !notes.isEmpty { fields.append("notes=\(notes.prefix(200))") }
            lines.append("- " + fields.joined(separator: " | "))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Parsing (pure — unit-testable without network)

    private struct LLMResponse: Decodable { let events: [LLMEvent] }
    private struct LLMEvent: Decodable {
        let id: String
        let category: String
        let direction: String?
        let tzOffsetHours: Int?
        let why: String?
    }

    static func parse(jsonString: String, rawEvents: [RawCalendarEvent]) -> [String: Categorization] {
        let byId = Dictionary(
            rawEvents.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first })
        guard let data = extractJSON(jsonString),
              let decoded = try? JSONDecoder().decode(LLMResponse.self, from: data) else {
            return [:]
        }
        var out: [String: Categorization] = [:]
        for item in decoded.events {
            guard let raw = byId[item.id] else { continue }
            out[raw.id] = Categorization(
                fingerprint: fingerprint(of: raw),
                category: RestAlgorithms.normalizedCategory(item.category),
                direction: item.direction.flatMap { $0 == "null" ? nil : $0 },
                tzOffsetHours: item.tzOffsetHours,
                why: item.why)
        }
        return out
    }

    /// Assemble display events + adaptations: skip neutral events, show future
    /// events, and keep past events only while their sleep impact lingers.
    static func buildResult(rawEvents: [RawCalendarEvent],
                            categorizations: [String: Categorization],
                            targetWake: String,
                            now: Date = Date()) -> Result {
        var events: [CalendarEvent] = []
        var adaptations: [Adaptation] = []
        for raw in rawEvents.sorted(by: { $0.start < $1.start }) {
            guard let c = categorizations[raw.id], c.category != "neutral",
                  isStillRelevant(category: c.category, tzOffsetHours: c.tzOffsetHours,
                                  end: raw.end, now: now) else { continue }

            let event = CalendarEvent(
                id: raw.id, title: raw.title,
                startTs: fmt(raw.start), endTs: fmt(raw.end),
                type: c.category, tzOffsetHours: c.tzOffsetHours, direction: c.direction)
            events.append(event)

            let r = RestAlgorithms.adapt(for: event, targetWake: targetWake)
            adaptations.append(Adaptation(
                eventId: raw.id, scenario: r.scenario,
                recommendation: r.recommendation, scienceBasis: r.scienceBasis,
                applied: false, whyItAffectsSleep: c.why))
        }
        return Result(events: events, adaptations: adaptations)
    }

    /// Future events always show. Past events only while they still shape the plan:
    /// jet-lag re-entrainment runs ~1 day per time zone crossed; late-night recovery
    /// guidance (anchored wake, early nap) applies through the following day.
    static func isStillRelevant(category: String, tzOffsetHours: Int?, end: Date, now: Date) -> Bool {
        guard end < now else { return true }
        let daysSince = now.timeIntervalSince(end) / 86400
        switch category {
        case "timezone_travel": return daysSince <= Double(max(1, abs(tzOffsetHours ?? 1)))
        case "social_jetlag":   return daysSince <= 1
        default:                return false
        }
    }

    /// Pull the JSON object out of a response that may be wrapped in prose or
    /// ```json fences.
    private static func extractJSON(_ s: String) -> Data? {
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}"), start < end {
            return String(s[start...end]).data(using: .utf8)
        }
        return s.data(using: .utf8)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; return f
    }()
    private static let ymdFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static func fmt(_ d: Date) -> String { dateFormatter.string(from: d) }
}
