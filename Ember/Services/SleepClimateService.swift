import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(WeatherKit)
import WeatherKit
#endif

struct SleepClimateSnapshot: Equatable {
    enum Risk: String {
        case low, moderate, high

        var label: String {
            switch self {
            case .low: return "Low climate risk"
            case .moderate: return "Warm night"
            case .high: return "Hot, sticky night"
            }
        }
    }

    let overnightLowC: Double
    let overnightHighC: Double
    let maxHumidity: Double?
    let risk: Risk
    let summary: String
    let guidance: String
}

@MainActor
final class SleepClimateService: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var lastError: String? = nil

    static var isSupported: Bool {
        #if canImport(WeatherKit) && canImport(CoreLocation)
        return true
        #else
        return false
        #endif
    }

    func refreshIfAuthorized(store: DataStore) async {
        #if canImport(CoreLocation)
        let status = CLLocationManager().authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        await refresh(store: store)
        #endif
    }

    func refresh(store: DataStore) async {
        #if canImport(WeatherKit) && canImport(CoreLocation)
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let location = try await currentLocation()
            let hourly = try await WeatherService().weather(for: location, including: .hourly)
            let snapshot = Self.snapshot(from: Array(hourly.forecast), calendar: .current)
            store.sleepClimate = snapshot
        } catch {
            store.sleepClimate = nil
            lastError = error.localizedDescription
        }
        #else
        store.sleepClimate = nil
        lastError = "Weather is unavailable in this build."
        #endif
    }

    #if canImport(WeatherKit) && canImport(CoreLocation)
    private let locationProvider = OneShotLocationProvider()

    private func currentLocation() async throws -> CLLocation {
        try await locationProvider.location()
    }

    private static func snapshot(from hourly: [HourWeather], calendar: Calendar) -> SleepClimateSnapshot? {
        let start = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        let end = calendar.date(byAdding: .hour, value: 12, to: start) ?? start.addingTimeInterval(12 * 3600)
        let overnight = hourly.filter { $0.date >= start && $0.date <= end }
        guard !overnight.isEmpty else { return nil }

        let temps = overnight.map { $0.temperature.converted(to: .celsius).value }
        let low = temps.min() ?? 0
        let high = temps.max() ?? low
        let humidity = overnight.map(\.humidity).max()
        let humid = humidity ?? 0

        let risk: SleepClimateSnapshot.Risk
        if high >= 27 || (high >= 25 && humid >= 0.70) {
            risk = .high
        } else if high >= 23 || (high >= 21 && humid >= 0.75) {
            risk = .moderate
        } else {
            risk = .low
        }

        let tempRange = "\(Int(low.rounded()))-\(Int(high.rounded()))C"
        let humidityText = humidity.map { " · humidity up to \(Int(($0 * 100).rounded()))%" } ?? ""
        let summary: String
        let guidance: String
        switch risk {
        case .low:
            summary = "Overnight forecast looks sleep-friendly: \(tempRange)\(humidityText)."
            guidance = "Keep your usual wind-down. No weather adjustment needed."
        case .moderate:
            summary = "A warm night may make sleep onset harder: \(tempRange)\(humidityText)."
            guidance = "Cool the room before bed, use lighter bedding, and hydrate earlier in the evening."
        case .high:
            summary = "Heat and humidity may raise sleep friction tonight: \(tempRange)\(humidityText)."
            guidance = "Pre-cool the bedroom, keep bedding light, avoid late alcohol, and treat the warm-up ritual as optional if the room is already hot."
        }

        return SleepClimateSnapshot(
            overnightLowC: low.rounded(),
            overnightHighC: high.rounded(),
            maxHumidity: humidity,
            risk: risk,
            summary: summary,
            guidance: guidance)
    }
    #endif
}

#if canImport(CoreLocation)
@MainActor
private final class OneShotLocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var wantsLocationAfterAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func location() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .notDetermined:
                wantsLocationAfterAuthorization = true
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                continuation.resume(throwing: CLError(.denied))
                self.continuation = nil
            @unknown default:
                continuation.resume(throwing: CLError(.locationUnknown))
                self.continuation = nil
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard wantsLocationAfterAuthorization else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            wantsLocationAfterAuthorization = false
            manager.requestLocation()
        case .denied, .restricted:
            wantsLocationAfterAuthorization = false
            continuation?.resume(throwing: CLError(.denied))
            continuation = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
#endif
