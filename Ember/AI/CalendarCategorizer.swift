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

    // MARK: - Public entry point

    static func categorize(rawEvents: [RawCalendarEvent],
                           targetWake: String,
                           client: LLMClient) async throws -> Result {
        guard !rawEvents.isEmpty else { return Result(events: [], adaptations: []) }
        let user = userPrompt(for: rawEvents)
        let raw = try await client.complete(system: systemPrompt, user: user)
        return parse(jsonString: raw, rawEvents: rawEvents, targetWake: targetWake)
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
            let startHour = cal.component(.hour, from: e.start)
            let endHour = cal.component(.hour, from: e.end)
            let hours = e.end.timeIntervalSince(e.start) / 3600
            var fields = [
                "id=\(e.id)",
                "title=\(e.title)",
                "start=\(iso.string(from: e.start)) (local hour \(startHour))",
                "end=\(iso.string(from: e.end)) (local hour \(endHour))",
                "durationHours=\(String(format: "%.1f", hours))",
                "allDay=\(e.isAllDay)"
            ]
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

    static func parse(jsonString: String, rawEvents: [RawCalendarEvent], targetWake: String) -> Result {
        let byId = Dictionary(uniqueKeysWithValues: rawEvents.map { ($0.id, $0) })
        guard let data = extractJSON(jsonString),
              let decoded = try? JSONDecoder().decode(LLMResponse.self, from: data) else {
            return Result(events: [], adaptations: [])
        }

        var events: [CalendarEvent] = []
        var adaptations: [Adaptation] = []
        for item in decoded.events {
            let category = RestAlgorithms.normalizedCategory(item.category)
            guard category != "neutral", let raw = byId[item.id] else { continue }

            let direction = item.direction.flatMap { $0 == "null" ? nil : $0 }
            let event = CalendarEvent(
                id: raw.id, title: raw.title,
                startTs: fmt(raw.start), endTs: fmt(raw.end),
                type: category, tzOffsetHours: item.tzOffsetHours, direction: direction)
            events.append(event)

            let r = RestAlgorithms.adapt(for: event, targetWake: targetWake)
            adaptations.append(Adaptation(
                eventId: raw.id, scenario: r.scenario,
                recommendation: r.recommendation, scienceBasis: r.scienceBasis,
                applied: false, whyItAffectsSleep: item.why))
        }
        events.sort { $0.startTs < $1.startTs }
        return Result(events: events, adaptations: adaptations)
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
    private static func fmt(_ d: Date) -> String { dateFormatter.string(from: d) }
}
