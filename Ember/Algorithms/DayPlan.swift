import Foundation

/// Builds a concrete, quantified sleep plan for a single night from the user's
/// targets, their warming prescription, and the day's calendar events. Pure and
/// testable. This is the deterministic "sleep math" the AI never touches:
/// required wake, recommended bedtime, the warming window, how much sleep an
/// event will cost, and a plain risk level.
enum SleepRiskLevel: String {
    case low, moderate, high
    var label: String {
        switch self {
        case .low: return "Low impact"
        case .moderate: return "Moderate impact"
        case .high: return "High impact"
        }
    }
}

struct DayPlan {
    /// The calendar day whose evening this night begins on.
    let day: Date
    var warmingStart: Date
    var warmingEnd: Date
    var bed: Date
    var wake: Date

    let sleepLossMin: Int
    let level: SleepRiskLevel
    let headline: String
    let detail: String
    /// Title of the event driving the plan (early start / late night), if any.
    let driverTitle: String?

    var sleepDurationMin: Int { max(0, Int(wake.timeIntervalSince(bed) / 60)) }
}

enum DayPlanner {

    static let windDownMin = 30          // buffer after a late event before bed
    static let defaultWarmingDurationMin = 12

    static func build(nightOf day: Date,
                      user: UserProfile,
                      warmingOffsetMin: Int,
                      warmingDurationMin: Int = defaultWarmingDurationMin,
                      prepBufferMin: Int,
                      events: [AgendaEvent],
                      calendar: Calendar = .current) -> DayPlan {
        let wakeDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day))!
        let (wh, wm) = hhmm(user.targetWakeTime) ?? (7, 0)
        let (bh, bm) = hhmm(user.targetBedTime) ?? (23, 0)

        let baseWake = at(wakeDay, hour: wh, minute: wm, calendar)
        let desiredSleepMin = ((wh * 60 + wm) - (bh * 60 + bm) + 1440) % 1440

        // Earliest obligation the next morning pulls the wake time (and prep) up.
        let morningWindowEnd = calendar.date(byAdding: .hour, value: 11, to: calendar.startOfDay(for: wakeDay))!
        let earlyStart = events
            .filter { $0.start >= calendar.startOfDay(for: wakeDay) && $0.start <= morningWindowEnd && !$0.isAllDay }
            .filter { $0.category == "early_obligation" || $0.start < baseWake }
            .map { $0.start }
            .min()
        var requiredWake = baseWake
        var driver: String? = nil
        if let es = earlyStart, let ev = events.first(where: { $0.start == es }) {
            let needed = calendar.date(byAdding: .minute, value: -prepBufferMin, to: es)!
            if needed < requiredWake { requiredWake = needed; driver = ev.title }
        }

        var recommendedBed = calendar.date(byAdding: .minute, value: -desiredSleepMin, to: requiredWake)!

        // A late evening event on `day` can push the feasible bedtime later.
        let eveningStart = at(day, hour: 18, minute: 0, calendar)
        let lateEvent = events
            .filter { $0.end > eveningStart && $0.start < wakeDay && !$0.isAllDay }
            .filter { $0.category == "social_jetlag" || $0.end >= recommendedBed }
            .max(by: { $0.end < $1.end })
        if let late = lateEvent {
            let feasible = calendar.date(byAdding: .minute, value: windDownMin, to: late.end)!
            if feasible > recommendedBed { recommendedBed = feasible; if driver == nil { driver = late.title } }
        }

        let bed = recommendedBed
        let availableMin = max(0, Int(requiredWake.timeIntervalSince(bed) / 60))
        let sleepLoss = max(0, desiredSleepMin - availableMin)

        let demanding = events.contains {
            $0.category == "demanding_event" &&
            $0.start >= calendar.startOfDay(for: wakeDay) && $0.start <= morningWindowEnd
        }

        let level: SleepRiskLevel
        if sleepLoss >= 60 { level = .high }
        else if sleepLoss >= 15 || demanding { level = .moderate }
        else { level = .low }

        var warmingStart = calendar.date(byAdding: .minute, value: -warmingOffsetMin, to: bed)!
        var warmingEnd = calendar.date(byAdding: .minute, value: warmingDurationMin, to: warmingStart)!
        while let conflict = events
            .filter({ !$0.isAllDay && $0.start < warmingEnd && $0.end > warmingStart })
            .max(by: { $0.end < $1.end }) {
            warmingStart = conflict.end
            warmingEnd = calendar.date(byAdding: .minute, value: warmingDurationMin, to: warmingStart)!
            if warmingStart >= bed { break }
        }

        let (headline, detail) = copy(level: level, sleepLoss: sleepLoss,
                                      driver: driver, demanding: demanding,
                                      bed: bed, wake: requiredWake, calendar: calendar)

        return DayPlan(day: day, warmingStart: warmingStart, warmingEnd: warmingEnd,
                       bed: bed, wake: requiredWake, sleepLossMin: sleepLoss,
                       level: level, headline: headline, detail: detail, driverTitle: driver)
    }

    private static func copy(level: SleepRiskLevel, sleepLoss: Int, driver: String?,
                             demanding: Bool, bed: Date, wake: Date, calendar: Calendar) -> (String, String) {
        let bedStr = clock(bed, calendar), wakeStr = clock(wake, calendar)
        switch level {
        case .low:
            return ("You're clear for a full night",
                    "Wind down for lights-out around \(bedStr) and you'll get your full sleep opportunity before \(wakeStr).")
        case .moderate:
            if demanding {
                return ("Protect tonight — big day tomorrow",
                        "A high-stakes event tomorrow rewards a solid night. Aim for lights-out by \(bedStr) and keep your \(wakeStr) wake time.")
            }
            let loss = sleepLoss >= 15 ? " You'd lose about \(fmtDur(sleepLoss)) of sleep versus your usual." : ""
            return ("Tighter window tonight",
                    "\(driver.map { "\($0) shifts things. " } ?? "")Move lights-out to \(bedStr) to reach \(wakeStr).\(loss)")
        case .high:
            return ("Sleep is squeezed tonight",
                    "\(driver.map { "\($0) leaves a short window. " } ?? "")Even lights-out at \(bedStr) gives under your usual night — about \(fmtDur(sleepLoss)) short. Front-load prep and start winding down early.")
        }
    }

    // MARK: - helpers

    private static func hhmm(_ s: String) -> (Int, Int)? {
        let p = s.split(separator: ":").compactMap { Int($0) }
        return p.count >= 2 ? (p[0], p[1]) : nil
    }
    private static func at(_ day: Date, hour: Int, minute: Int, _ cal: Calendar) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
    private static func clock(_ d: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
