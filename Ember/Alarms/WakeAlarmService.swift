import Foundation
import SwiftUI
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit

/// AlarmKit requires a metadata type on its attributes even when there's
/// nothing extra to attach.
@available(iOS 26.1, *)
struct EmberAlarmMetadata: AlarmMetadata {}
#endif

/// Schedules EMBER's wake alarm through AlarmKit (iOS 26+): a real system-level
/// alarm that breaks through Silent mode and Focus. AlarmKit cannot modify the
/// Clock app's alarms or the Health sleep schedule — this is the app's own
/// alarm, set from the plan's target wake time. It uses an alert-only
/// presentation (no countdown), which avoids needing a widget extension.
@MainActor
final class WakeAlarmService: ObservableObject {
    /// "HH:mm" of the currently scheduled wake alarm; nil when none is set.
    @Published var scheduledTime: String? = nil
    @Published var lastError: String? = nil

    /// When on, the background refresh keeps the alarm armed nightly and pulls
    /// it earlier ahead of early obligations, notifying the user why.
    @Published var autoAdaptEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoAdaptEnabled, forKey: Keys.auto)
            if autoAdaptEnabled {
                Task {
                    _ = try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound])
                }
            }
        }
    }

    /// Minutes of prep time the user needs in the morning — protected between
    /// waking and an early obligation. Set during onboarding, editable later.
    @Published var prepBufferMin: Int {
        didSet { UserDefaults.standard.set(prepBufferMin, forKey: Keys.prep) }
    }

    /// Whether this build + OS can schedule AlarmKit alarms at all.
    static var isSupported: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) { return true }
        #endif
        return false
    }

    private enum Keys {
        static let id = "ember.wakeAlarmID"
        static let time = "ember.wakeAlarmTime"
        static let lastTime = "ember.wakeAlarmLastTime"   // survives firing, for re-arm
        static let auto = "ember.wakeAlarmAutoAdapt"
        static let prep = "ember.morningPrepMin"
    }

    init() {
        autoAdaptEnabled = UserDefaults.standard.bool(forKey: Keys.auto)
        let savedPrep = UserDefaults.standard.integer(forKey: Keys.prep)
        prepBufferMin = savedPrep > 0 ? savedPrep : 45
        Task { await syncFromSystem() }
    }

    // MARK: - Permission requests (used by onboarding)

    /// Ask for AlarmKit permission up front. Returns false where unavailable.
    func requestAlarmAccess() async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            let state = try? await AlarmManager.shared.requestAuthorization()
            return state == .authorized
        }
        #endif
        return false
    }

    /// Ask for notification permission (the "why we moved your alarm" alerts).
    @discardableResult
    func requestNotificationAccess() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Schedule a one-off local reminder (e.g. "start winding down") at a given
    /// date. Requests notification permission if needed. Returns success.
    @discardableResult
    func addReminder(at date: Date, title: String, body: String, id: String = UUID().uuidString) async -> Bool {
        guard date > Date() else { return false }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined { _ = await requestNotificationAccess() }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            Haptics.success()
            return true
        } catch { return false }
    }

    /// Schedule (or move) the one-shot wake alarm to the next occurrence of `hhmm`.
    func setWakeAlarm(at hhmm: String) async {
        #if canImport(AlarmKit)
        guard #available(iOS 26.1, *) else {
            lastError = "Wake alarms need iOS 26.1 or later."
            return
        }
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else {
            lastError = "Couldn't read wake time \(hhmm)."
            return
        }
        do {
            let auth = try await AlarmManager.shared.requestAuthorization()
            guard auth == .authorized else {
                lastError = "Alarm permission denied. Enable it in Settings → Ember."
                return
            }
            cancelExisting()
            let schedule = Alarm.Schedule.relative(.init(
                time: .init(hour: parts[0], minute: parts[1]),
                repeats: .never))
            let stopButton = AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.fill")
            let presentation = AlarmPresentation(
                alert: .init(
                    title: "Wake up — EMBER",
                    stopButton: stopButton))
            let attributes = AlarmAttributes<EmberAlarmMetadata>(
                presentation: presentation, tintColor: Theme.ember)
            let configuration = AlarmManager.AlarmConfiguration<EmberAlarmMetadata>.alarm(
                schedule: schedule,
                attributes: attributes)
            let id = UUID()
            _ = try await AlarmManager.shared.schedule(
                id: id,
                configuration: configuration)
            UserDefaults.standard.set(id.uuidString, forKey: Keys.id)
            UserDefaults.standard.set(hhmm, forKey: Keys.time)
            UserDefaults.standard.set(hhmm, forKey: Keys.lastTime)
            scheduledTime = hhmm
            lastError = nil
            Haptics.success()
        } catch {
            lastError = error.localizedDescription
        }
        #else
        lastError = "AlarmKit isn't available in this build."
        #endif
    }

    func cancelWakeAlarm() {
        cancelExisting()
        scheduledTime = nil
    }

    /// One-shot alarms disappear from the system store once they fire or are
    /// stopped, so reconcile our persisted alarm with what's still scheduled.
    func syncFromSystem() async {
        #if canImport(AlarmKit)
        guard #available(iOS 26.1, *),
              let idString = UserDefaults.standard.string(forKey: Keys.id),
              let id = UUID(uuidString: idString) else { return }
        let stillScheduled = ((try? AlarmManager.shared.alarms) ?? []).contains { $0.id == id }
        if stillScheduled {
            scheduledTime = UserDefaults.standard.string(forKey: Keys.time)
        } else {
            clearPersisted()
            scheduledTime = nil
        }
        #endif
    }

    private func cancelExisting() {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *),
           let idString = UserDefaults.standard.string(forKey: Keys.id),
           let id = UUID(uuidString: idString) {
            try? AlarmManager.shared.cancel(id: id)
        }
        #endif
        clearPersisted()
    }

    private func clearPersisted() {
        UserDefaults.standard.removeObject(forKey: Keys.id)
        UserDefaults.standard.removeObject(forKey: Keys.time)
    }

    // MARK: - Background auto-adaptation

    /// Called from the background refresh task. Two jobs:
    /// 1. If an early_obligation event starts within 24h and its needed wake time
    ///    (start − prep buffer) is before the alarm's next fire, pull the alarm
    ///    earlier and notify the user with the event's "why".
    /// 2. If the one-shot alarm already fired, re-arm it at its usual time.
    /// Only ever moves an alarm the user has set (or set previously) — it never
    /// invents one from nothing.
    func autoAdapt(events: [CalendarEvent], adaptations: [Adaptation], now: Date = Date()) async {
        guard autoAdaptEnabled, Self.isSupported else { return }
        await syncFromSystem()
        guard let baseTime = scheduledTime ?? UserDefaults.standard.string(forKey: Keys.lastTime)
        else { return }
        let baseFire = nextOccurrence(of: baseTime, after: now)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        var earliest: (event: CalendarEvent, wake: Date)? = nil
        for e in events where RestAlgorithms.normalizedCategory(e.type) == "early_obligation" {
            guard let start = df.date(from: e.startTs) else { continue }
            let wake = start.addingTimeInterval(-Double(prepBufferMin) * 60)
            guard wake > now, start <= now.addingTimeInterval(24 * 3600), wake < baseFire else { continue }
            if earliest == nil || wake < earliest!.wake { earliest = (e, wake) }
        }

        if let hit = earliest {
            let hhmm = hhmmString(hit.wake)
            guard hhmm != scheduledTime else { return }
            await setWakeAlarm(at: hhmm)
            guard lastError == nil else { return }
            let why = adaptations.first { $0.eventId == hit.event.id }?.whyItAffectsSleep
            await notify(
                title: "Wake alarm moved to \(hhmm)",
                body: "\(hit.event.title) starts at \(String(hit.event.startTs.suffix(5))). "
                    + (why ?? "Waking \(prepBufferMin) min ahead protects a full sleep opportunity."))
        } else if scheduledTime == nil {
            await setWakeAlarm(at: baseTime)
            guard lastError == nil else { return }
            await notify(
                title: "Wake alarm re-armed for \(baseTime)",
                body: "No early events tomorrow — back on your regular wake anchor.")
        }
    }

    private func notify(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        try? await center.add(UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// Next absolute fire date of an "HH:mm" alarm after `now`.
    private func nextOccurrence(of hhmm: String, after now: Date) -> Date {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return now }
        return Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: parts[0], minute: parts[1]),
            matchingPolicy: .nextTime) ?? now
    }

    private func hhmmString(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
