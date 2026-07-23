import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

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
        return types
    }

    func requestAuthorization() async {
        guard isAvailable else { lastError = "Health data not available on this device."; return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorized = true
            await fetchLastNight()
        } catch {
            lastError = error.localizedDescription
        }
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
        return SleepInterval(kind: kind, start: sample.startDate, end: sample.endDate)
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
    #else
    var isAvailable: Bool { false }
    func requestAuthorization() async { lastError = "HealthKit not compiled in." }
    func fetchLastNight() async {}
    func fetchNights(daysBack: Int = 60) async -> [NightSample] { [] }
    #endif
}
