import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Apple Health integration. Reads sleep analysis (asleep intervals) to compute
/// last night's total sleep time, which EMBER can feed into the thermal/CBT-I
/// logs instead of manual entry. Guarded so the project still builds on targets
/// without HealthKit.
@MainActor
final class HealthManager: ObservableObject {
    @Published var authorized = false
    @Published var lastNightTSTMin: Int?
    @Published var lastError: String?

    #if canImport(HealthKit)
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard isAvailable else { lastError = "Health data not available on this device."; return }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let read: Set<HKObjectType> = [sleepType]
        do {
            try await store.requestAuthorization(toShare: [], read: read)
            authorized = true
            await fetchLastNight()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Sum "asleep" category samples from the last 24h into total sleep minutes.
    func fetchLastNight() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let end = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)

        let samples: [HKCategorySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: sleepType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }

        // "Asleep" values differ by iOS version — accept core/deep/REM/unspecified asleep.
        let asleepValues: Set<Int> = {
            var s: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue]
            if #available(iOS 16.0, *) {
                s.formUnion([
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ])
            }
            return s
        }()

        let seconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        lastNightTSTMin = seconds > 0 ? Int(seconds / 60) : nil
    }
    #else
    var isAvailable: Bool { false }
    func requestAuthorization() async { lastError = "HealthKit not compiled in." }
    func fetchLastNight() async {}
    #endif
}
