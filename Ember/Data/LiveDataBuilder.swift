import Foundation

/// Turns real `NightSample`s (from HealthKit) and calendar events (from
/// EventKit) into the model arrays the views already consume. Charts show the
/// measured metrics; prescriptions are produced by running the *existing* pure
/// engines in `RestAlgorithms` over those measurements — nothing is fabricated.
enum LiveDataBuilder {

    /// Nights per thermal titration block.
    static let blockSize = 3

    /// Sleep clusters shorter than this are treated as naps, not nights, so an
    /// afternoon nap can't skew prescriptions or the derived target times.
    static let mainSleepMinTstMin = 180

    struct Built {
        var user: UserProfile
        var sleepLogs: [SleepLog]
        var prescriptions: [ThermalPrescription]
        var cbtiLogs: [CBTILog]
        var cbtiPrescriptions: [CBTIPrescription]
    }

    // Calendar events and their adaptations are produced separately by the LLM
    // `CalendarCategorizer`, not here.
    static func build(nights rawNights: [NightSample],
                      name: String,
                      warmingMethod: String,
                      calendar: Calendar = .current) -> Built {
        let nights = rawNights.sorted { $0.date < $1.date }
            .filter { $0.tstMin >= mainSleepMinTstMin }

        let sleepLogs = nights.map { n in
            let cal = localCalendar(calendar, n.timeZone)
            return SleepLog(date: n.date,
                     lightsOut: hhmm(n.lightsOut, cal),
                     sleepOnset: hhmm(n.sleepOnset, cal),
                     solMin: n.solMin,
                     wakeTime: hhmm(n.finalWake, cal),
                     tstMin: n.tstMin,
                     ritualDone: false,          // not knowable from Health data
                     prescribedOffsetMin: nil,
                     phase: "observed")
        }

        let prescriptions = thermalPrescriptions(nights: nights, warmingMethod: warmingMethod)

        let cbtiLogs = nights.map { n in
            let cal = localCalendar(calendar, n.timeZone)
            return CBTILog(date: n.date,
                    timeToBed: hhmm(n.lightsOut, cal),
                    sleepOnsetMin: Int(n.solMin.rounded()),
                    wasoMin: n.wasoMin,
                    finalWakeTime: hhmm(n.finalWake, cal),
                    tstMin: n.tstMin,
                    tibMin: n.tibMin,
                    sePct: n.sePct)
        }

        let cbtiPrescriptions = cbtiWeeklyPrescriptions(nights: nights, calendar: calendar)

        let user = deriveProfile(nights: nights, name: name, warmingMethod: warmingMethod,
                                 latestRx: prescriptions.last, calendar: calendar)

        return Built(user: user, sleepLogs: sleepLogs, prescriptions: prescriptions,
                     cbtiLogs: cbtiLogs, cbtiPrescriptions: cbtiPrescriptions)
    }

    // MARK: - Thermal titration (Module A)

    private static func thermalPrescriptions(nights: [NightSample], warmingMethod: String) -> [ThermalPrescription] {
        let blocks = stride(from: 0, to: nights.count, by: blockSize).map {
            Array(nights[$0..<min($0 + blockSize, nights.count)])
        }
        guard !blocks.isEmpty else { return [] }

        var result: [ThermalPrescription] = []
        var currentOffset = 90                 // literature default (Haghayegh 2019)
        var priorMedian: Double? = nil
        var pending: RestAlgorithms.ThermalDecision? = nil

        for (i, block) in blocks.enumerated() {
            let m = median(block.map { $0.solMin })
            let action: String, converged: Bool, rationale: String
            if i == 0 {
                action = RestAlgorithms.ThermalAction.initiation.rawValue
                converged = false
                rationale = String(format: "Baseline habitual SOL %.1f min. Initiate warming ritual %d min before bed (literature default, Haghayegh 2019).", m, currentOffset)
            } else if let d = pending {
                action = d.action.rawValue
                converged = d.converged
                rationale = d.rationale
            } else {
                action = RestAlgorithms.ThermalAction.continue.rawValue
                converged = false
                rationale = ""
            }
            result.append(ThermalPrescription(
                block: i + 1, prescribedOffsetMin: currentOffset,
                warmingMethod: warmingMethod, durationMin: 12, tempBand: "40–42C",
                medianSolPrior: priorMedian, action: action, converged: converged, rationale: rationale))

            let d = RestAlgorithms.nextOffset(currentOffsetMin: currentOffset, medianSOL: m, priorMedianSOL: priorMedian)
            currentOffset = d.nextOffsetMin
            priorMedian = m
            pending = d
        }
        // If the most recent block's own SOL already meets target, the current
        // offset IS the converged, personalized one — reflect that on it.
        if let last = pending, last.converged, var current = result.last {
            current = ThermalPrescription(
                block: current.block, prescribedOffsetMin: current.prescribedOffsetMin,
                warmingMethod: current.warmingMethod, durationMin: current.durationMin,
                tempBand: current.tempBand, medianSolPrior: current.medianSolPrior,
                action: RestAlgorithms.ThermalAction.holdConverged.rawValue, converged: true,
                rationale: last.rationale)
            result[result.count - 1] = current
        }
        return result
    }

    // MARK: - CBT-I sleep restriction (Module B)

    private static func cbtiWeeklyPrescriptions(nights: [NightSample], calendar: Calendar) -> [CBTIPrescription] {
        // Group nights by the week of their final-wake day, judged in each
        // night's own recording zone and keyed by the LOCAL week-start date
        // string — so the same nominal week in Zurich and Shanghai is one group,
        // and a night near a week boundary lands where the sleeper lived it.
        let groups = Dictionary(grouping: nights) { n -> String in
            let cal = localCalendar(calendar, n.timeZone)
            let start = cal.dateInterval(of: .weekOfYear, for: n.finalWake)?.start ?? n.finalWake
            return ymd(cal).string(from: start)
        }
        let weeks = groups.keys.sorted().map { key in (start: key, nights: groups[key]!.sorted { $0.date < $1.date }) }
        guard let first = weeks.first else { return [] }

        var result: [CBTIPrescription] = []
        var currentTib = roundTo5(Int(mean(first.nights.map { Double($0.tibMin) })))
        var priorSE: Double? = nil
        var pending: RestAlgorithms.CBTIDecision? = nil

        for (i, wk) in weeks.enumerated() {
            let avgSE = mean(wk.nights.map { $0.sePct }).rounded(toPlaces: 1)
            let avgTst = Int(mean(wk.nights.map { Double($0.tstMin) }).rounded())
            let mid = wk.nights[wk.nights.count / 2]

            let action: String, rationale: String
            if i == 0 {
                action = RestAlgorithms.CBTIAction.baseline.rawValue
                rationale = String(format: "Baseline observation week — avg SE %.1f%%. Time-in-bed titrates to sleep efficiency from here.", avgSE)
            } else if let d = pending {
                action = d.action.rawValue
                rationale = d.rationale
            } else {
                action = RestAlgorithms.CBTIAction.hold.rawValue
                rationale = ""
            }
            let midCal = localCalendar(calendar, mid.timeZone)
            result.append(CBTIPrescription(
                week: i + 1, weekStart: wk.start, tibMin: currentTib,
                wakeTime: hhmm(mid.finalWake, midCal), bedTime: hhmm(mid.lightsOut, midCal),
                avgSePrior: priorSE, action: action, rationale: rationale))

            let d = RestAlgorithms.nextTIB(currentTibMin: currentTib, avgSE: avgSE, avgTstMin: avgTst)
            currentTib = d.nextTibMin
            priorSE = avgSE
            pending = d
        }
        return result
    }

    // MARK: - Profile

    private static func deriveProfile(nights: [NightSample], name: String, warmingMethod: String,
                                      latestRx: ThermalPrescription?, calendar: Calendar) -> UserProfile {
        let baseline = Array(nights.prefix(7))
        let baselineSol = baseline.isEmpty ? 0 : median(baseline.map { $0.solMin })
        let baselineTst = baseline.isEmpty ? 0 : Int(mean(baseline.map { Double($0.tstMin) }).rounded())
        // Target times come from the median clock time across recent nights, so
        // one odd night (a 7am crash after a late one) can't hijack the plan.
        // Each night's clock time is taken in its own recording time zone.
        let recent = nights.suffix(14)
        let bed = recent.isEmpty ? "23:00"
            : hhmmString(medianClockMinutes(recent.map { ($0.lightsOut, $0.timeZone) }, calendar, wrapsMidnight: true))
        let wake = recent.isEmpty ? "07:00"
            : hhmmString(medianClockMinutes(recent.map { ($0.finalWake, $0.timeZone) }, calendar, wrapsMidnight: false))

        return UserProfile(
            id: "healthkit-user",
            name: name,
            requiredRiseTime: wake,
            targetBedTime: bed,
            targetWakeTime: wake,
            baselineSolMin: baselineSol,
            baselineAvgTstMin: baselineTst,
            currentOffsetMin: latestRx?.prescribedOffsetMin ?? 90,
            warmingMethod: warmingMethod,
            phase: (latestRx?.converged ?? false) ? "maintenance" : "titration")
    }

    // MARK: - Small helpers

    private static func hhmm(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
    private static func hhmmString(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
    /// Median clock time (minutes since midnight), each date read in its own
    /// recording time zone. Bedtimes cluster around midnight, so they're shifted
    /// by 12h before the median to keep the cluster contiguous (23:50 and 00:10
    /// must not average to noon).
    private static func medianClockMinutes(_ times: [(date: Date, tz: TimeZone?)],
                                           _ calendar: Calendar, wrapsMidnight: Bool) -> Int {
        let shift = wrapsMidnight ? 720 : 0
        let mins = times.map { t -> Double in
            let c = localCalendar(calendar, t.tz).dateComponents([.hour, .minute], from: t.date)
            return Double(((c.hour ?? 0) * 60 + (c.minute ?? 0) + shift) % 1440)
        }
        return ((Int(median(mins).rounded()) % 1440) - shift + 1440) % 1440
    }
    /// The base calendar re-zoned to a night's recording time zone (if known).
    private static func localCalendar(_ base: Calendar, _ tz: TimeZone?) -> Calendar {
        guard let tz else { return base }
        var c = base; c.timeZone = tz; return c
    }
    private static func ymd(_ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter(); f.calendar = calendar; f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"; return f
    }
    private static func mean(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0,+) / Double(xs.count) }
    private static func median(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        let m = s.count / 2
        return s.count.isMultiple(of: 2) ? (s[m - 1] + s[m]) / 2 : s[m]
    }
    private static func roundTo5(_ n: Int) -> Int { Int((Double(n) / 5).rounded()) * 5 }
}
