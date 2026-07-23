import Foundation
#if canImport(EventKit)
import EventKit
#endif

/// A raw calendar event, decoupled from EventKit, handed to the LLM categorizer.
struct RawCalendarEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
}

/// Reads the user's real calendar (EventKit) and returns raw events. Semantic
/// categorization into sleep-relevant classes is done downstream by the LLM
/// (`CalendarCategorizer`), not here. Guarded so the project still builds where
/// EventKit is unavailable.
@MainActor
final class CalendarService: ObservableObject {
    @Published var authorized = false
    @Published var lastError: String?

    #if canImport(EventKit)
    private let store = EKEventStore()

    var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    func requestAccess() async {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            authorized = granted
            if !granted { lastError = "Calendar access denied. Enable it in Settings." }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Fetch raw events spanning the recent past and near future. The past window
    /// lets the agent give recovery advice (e.g. after a late night), the future
    /// window lets it pre-adapt before a disruption.
    func fetchRawEvents(daysBack: Int = 7, daysAhead: Int = 14) async -> [RawCalendarEvent] {
        guard isAuthorized else { return [] }
        let cal = Calendar.current
        let now = Date()
        guard let start = cal.date(byAdding: .day, value: -daysBack, to: now),
              let end = cal.date(byAdding: .day, value: daysAhead, to: now) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .compactMap { ev in
                guard let s = ev.startDate, let e = ev.endDate else { return nil }
                return RawCalendarEvent(
                    id: ev.eventIdentifier ?? UUID().uuidString,
                    title: ev.title ?? "Event",
                    start: s, end: e, isAllDay: ev.isAllDay,
                    location: ev.location, notes: ev.notes)
            }
    }
    #else
    var isAuthorized: Bool { false }
    func requestAccess() async { lastError = "EventKit not compiled in." }
    func fetchRawEvents(daysBack: Int = 7, daysAhead: Int = 14) async -> [RawCalendarEvent] { [] }
    #endif
}
