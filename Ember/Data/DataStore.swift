import Foundation
import Combine

/// Central observable store. Loads validated seed data from the bundle and
/// exposes it to the SwiftUI views. Apple Health, when authorized, augments the
/// thermal log with last night's real sleep (see HealthManager).
@MainActor
final class DataStore: ObservableObject {
    @Published var user: UserProfile
    @Published var sleepLogs: [SleepLog]
    @Published var prescriptions: [ThermalPrescription]
    @Published var cbtiLogs: [CBTILog]
    @Published var cbtiPrescriptions: [CBTIPrescription]
    @Published var calendarEvents: [CalendarEvent]
    @Published var adaptations: [Adaptation]
    @Published var pod: Pod
    @Published var chat: [ChatMessage] = []

    // Live Apple Health readout (nil until authorized + fetched)
    @Published var healthLastNightTST: Int? = nil
    @Published var healthAuthorized: Bool = false

    init() {
        let bundleSeed = DataStore.loadSeed()
        user = bundleSeed.user
        sleepLogs = bundleSeed.sleepLogs
        prescriptions = bundleSeed.prescriptions
        cbtiLogs = bundleSeed.cbtiLogs
        cbtiPrescriptions = bundleSeed.cbtiPrescriptions
        calendarEvents = bundleSeed.calendarEvents
        adaptations = bundleSeed.adaptations
        pod = bundleSeed.pod
        chat = [ChatMessage(role: .coach,
            content: "Hi \(bundleSeed.user.name) — I'm your rest coach. Ask me why any prescription changed, or tap a suggested question below.")]
    }

    static func loadSeed() -> SeedBundle {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("seed.json missing from bundle")
        }
        do { return try JSONDecoder().decode(SeedBundle.self, from: data) }
        catch { fatalError("seed decode failed: \(error)") }
    }

    // Derived: current thermal prescription (latest block)
    var currentThermalRx: ThermalPrescription? { prescriptions.max(by: { $0.block < $1.block }) }
    // Derived: current CBT-I prescription (latest week)
    var currentCBTIRx: CBTIPrescription? { cbtiPrescriptions.max(by: { $0.week < $1.week }) }

    var thermalConverged: Bool { currentThermalRx?.converged ?? false }
}
