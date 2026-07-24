import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// One hourly input bucket for EMBER's non-medical daily energy estimate.
struct DailyEnergyInput: Identifiable {
    let time: Date
    let averageHeartRate: Double?
    let averageHRV: Double?
    let activeEnergyKcal: Double
    let steps: Double
    let asleepMinutes: Double

    var id: Date { time }
}

struct DailyEnergyDay {
    let buckets: [DailyEnergyInput]
    let restingHeartRateBaseline: Double?
    let hrvBaseline: Double?
}

/// Apple Health integration. Reads sleep analysis (plus overnight heart rate and
/// HRV) and turns it into the `NightSample`s that drive EMBER's charts and
/// prescriptions instead of hand-logged data. Guarded so the project still
/// builds on targets without HealthKit.
@MainActor
final class HealthManager: ObservableObject {
    @Published var authorized = false
    @Published var lastNightTSTMin: Int?
    @Published var lastError: String?

    #if canImport(HealthKit)
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(rhr) }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeEnergy) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        return types
    }

    /// Set once the user has connected, so later launches reconnect silently.
    /// (HealthKit never reveals read-permission status, so this is the only signal.)
    private static let connectedOnceKey = "ember.healthConnectedOnce"

    func requestAuthorization() async {
        guard isAvailable else { lastError = "Health data not available on this device."; return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorized = true
            UserDefaults.standard.set(true, forKey: Self.connectedOnceKey)
            await fetchLastNight()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Restore the connection on launch if the user connected before.
    /// `requestAuthorization` shows no sheet once all types have been determined,
    /// so this never prompts — first-time users still tap Connect explicitly.
    func autoConnect() async {
        guard !authorized, isAvailable,
              UserDefaults.standard.bool(forKey: Self.connectedOnceKey) else { return }
        await requestAuthorization()
    }

    /// Sum "asleep" category samples from the last 24h into total sleep minutes.
    /// Kept for the Home "last night" card, independent of the full night history.
    func fetchLastNight() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let end = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        let samples = await categorySamples(sleepType, predicate)
        let seconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        lastNightTSTMin = seconds > 0 ? Int(seconds / 60) : nil
    }

    /// Fetch and derive per-night sleep metrics for the last `daysBack` days,
    /// overlaying mean overnight heart rate and HRV where available.
    func fetchNights(daysBack: Int = 60) async -> [NightSample] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -daysBack, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        let samples = await categorySamples(sleepType, predicate)
        let intervals = samples.compactMap { interval(from: $0) }
        var nights = SleepMetrics.nights(from: intervals)
        guard !nights.isEmpty else { return [] }

        // Overlay heart-rate / HRV: fetch once across the window, bucket by night.
        let hr = await quantitySamples(.heartRate, predicate)
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let hrv = await quantitySamples(.heartRateVariabilitySDNN, predicate)
        let ms = HKUnit.secondUnit(with: .milli)

        for i in nights.indices {
            let window = nights[i].lightsOut...nights[i].finalWake
            let hrValues = hr.filter { window.contains($0.startDate) }.map { $0.quantity.doubleValue(for: bpm) }
            let hrvValues = hrv.filter { window.contains($0.startDate) }.map { $0.quantity.doubleValue(for: ms) }
            if !hrValues.isEmpty { nights[i].avgHRBpm = (hrValues.reduce(0,+) / Double(hrValues.count)).rounded() }
            if !hrvValues.isEmpty { nights[i].hrvMs = (hrvValues.reduce(0,+) / Double(hrvValues.count)).rounded() }
        }
        return nights
    }

    /// Reads the signals needed for an hourly, today-only energy timeline. Apple
    /// Watch writes these samples opportunistically, so absent readings remain
    /// nil rather than being presented as continuously measured data.
    func fetchTodayEnergy() async -> DailyEnergyDay? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let now = Date()
        let todayPredicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])
        let baselineStart = calendar.date(byAdding: .day, value: -21, to: now)!
        let baselinePredicate = HKQuery.predicateForSamples(withStart: baselineStart, end: now, options: [])

        let heartRate = await quantitySamples(.heartRate, todayPredicate)
        let hrv = await quantitySamples(.heartRateVariabilitySDNN, todayPredicate)
        let activeEnergy = await quantitySamples(.activeEnergyBurned, todayPredicate)
        let steps = await quantitySamples(.stepCount, todayPredicate)
        let sleep = await categorySamples(sleepType, todayPredicate)
        let restingHR = await quantitySamples(.restingHeartRate, baselinePredicate)
        let baselineHRV = await quantitySamples(.heartRateVariabilitySDNN, baselinePredicate)

        let bpm = HKUnit.count().unitDivided(by: .minute())
        let milliseconds = HKUnit.secondUnit(with: .milli)
        let kilocalories = HKUnit.kilocalorie()
        let count = HKUnit.count()
        let hourCount = max(1, calendar.dateComponents([.hour], from: start, to: now).hour ?? 0) + 1

        let buckets = (0..<hourCount).compactMap { offset -> DailyEnergyInput? in
            guard let hourStart = calendar.date(byAdding: .hour, value: offset, to: start) else { return nil }
            let hourEnd = min(calendar.date(byAdding: .hour, value: 1, to: hourStart)!, now)
            guard hourEnd > hourStart else { return nil }
            let range = hourStart...hourEnd
            let hrValues = heartRate.filter { range.contains($0.startDate) }.map { $0.quantity.doubleValue(for: bpm) }
            let hrvValues = hrv.filter { range.contains($0.startDate) }.map { $0.quantity.doubleValue(for: milliseconds) }
            let energyValues = activeEnergy.filter { range.contains($0.startDate) }.map { $0.quantity.doubleValue(for: kilocalories) }
            let stepValues = steps.filter { range.contains($0.startDate) }.map { $0.quantity.doubleValue(for: count) }
            let asleepMinutes = sleep
                .filter { asleepValues.contains($0.value) }
                .reduce(0.0) { total, sample in
                    let overlapStart = max(sample.startDate, hourStart)
                    let overlapEnd = min(sample.endDate, hourEnd)
                    return total + max(0, overlapEnd.timeIntervalSince(overlapStart) / 60)
                }
            return DailyEnergyInput(
                time: hourStart,
                averageHeartRate: hrValues.isEmpty ? nil : hrValues.reduce(0, +) / Double(hrValues.count),
                averageHRV: hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count),
                activeEnergyKcal: energyValues.reduce(0, +),
                steps: stepValues.reduce(0, +),
                asleepMinutes: asleepMinutes)
        }
        let rhrValues = restingHR.map { $0.quantity.doubleValue(for: bpm) }.filter { $0 > 0 }
        let hrvValues = baselineHRV.map { $0.quantity.doubleValue(for: milliseconds) }.filter { $0 > 0 }
        return DailyEnergyDay(
            buckets: buckets,
            restingHeartRateBaseline: median(rhrValues),
            hrvBaseline: median(hrvValues))
    }

    // MARK: - Helpers

    /// "Asleep" values differ by iOS version — accept core/deep/REM/unspecified asleep.
    private var asleepValues: Set<Int> {
        var s: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue]
        if #available(iOS 16.0, *) {
            s.formUnion([
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ])
        }
        return s
    }

    private func interval(from sample: HKCategorySample) -> SleepInterval? {
        let kind: SleepInterval.Kind
        if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
            kind = .inBed
        } else if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
            kind = .awake
        } else if asleepValues.contains(sample.value) {
            kind = .asleep
        } else {
            return nil
        }
        // Sleep samples carry the zone they were recorded in (Apple Watch sets it);
        // without it, clock times fall back to the device's current zone.
        let tz = (sample.metadata?[HKMetadataKeyTimeZone] as? String)
            .flatMap(TimeZone.init(identifier:))
        return SleepInterval(kind: kind, start: sample.startDate, end: sample.endDate, timeZone: tz)
    }

    private func categorySamples(_ type: HKCategoryType, _ predicate: NSPredicate) async -> [HKCategorySample] {
        await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
    }

    private func quantitySamples(_ id: HKQuantityTypeIdentifier, _ predicate: NSPredicate) async -> [HKQuantitySample] {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return [] }
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                cont.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(q)
        }
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
    #else
    var isAvailable: Bool { false }
    func requestAuthorization() async { lastError = "HealthKit not compiled in." }
    func autoConnect() async {}
    func fetchLastNight() async {}
    func fetchNights(daysBack: Int = 60) async -> [NightSample] { [] }
    func fetchTodayEnergy() async -> DailyEnergyDay? { nil }
    #endif
}
