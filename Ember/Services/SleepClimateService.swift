import Foundation
#if canImport(CoreLocation)
import CoreLocation
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
    let source: String
    let locationName: String?
}

@MainActor
final class SleepClimateService: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var lastError: String? = nil

    static var isSupported: Bool {
        #if canImport(CoreLocation)
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
        #if canImport(CoreLocation)
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let location = try await currentLocation()
            let response = try await fetchForecast(for: location)
            let locationName = await placeName(for: location)
            let snapshot = Self.snapshot(from: response, calendar: .current, locationName: locationName)
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

    #if canImport(CoreLocation)
    private let locationProvider = OneShotLocationProvider()

    private func currentLocation() async throws -> CLLocation {
        try await locationProvider.location()
    }

    private func fetchForecast(for location: CLLocation) async throws -> OpenMeteoForecast {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", location.coordinate.longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,relative_humidity_2m"),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components?.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(OpenMeteoForecast.self, from: data)
    }

    private func placeName(for location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                let place = placemarks?.first
                let locality = place?.locality ?? place?.subLocality
                let region = place?.administrativeArea
                let country = place?.country

                if let locality, let region, locality != region {
                    continuation.resume(returning: "\(locality), \(region)")
                } else if let locality {
                    continuation.resume(returning: locality)
                } else if let region, let country, region != country {
                    continuation.resume(returning: "\(region), \(country)")
                } else {
                    continuation.resume(returning: country)
                }
            }
        }
    }

    private static func snapshot(from forecast: OpenMeteoForecast, calendar: Calendar, locationName: String?) -> SleepClimateSnapshot? {
        let start = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        let end = calendar.date(byAdding: .hour, value: 12, to: start) ?? start.addingTimeInterval(12 * 3600)
        let points = forecast.hourly.points(timeZoneIdentifier: forecast.timezone)
        let overnight = points.filter { $0.date >= start && $0.date <= end }
        guard !overnight.isEmpty else { return nil }

        let temps = overnight.map(\.temperatureC)
        let low = temps.min() ?? 0
        let high = temps.max() ?? low
        let humidityPct = overnight.compactMap(\.humidity).max()
        let humidity = humidityPct.map { $0 / 100 }
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
        let humidityText = humidityPct.map { " · humidity up to \(Int($0.rounded()))%" } ?? ""
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
            guidance: guidance,
            source: "Open-Meteo",
            locationName: locationName)
    }
    #endif
}

#if canImport(CoreLocation)
private struct OpenMeteoForecast: Decodable {
    let timezone: String?
    let hourly: OpenMeteoHourly
}

private struct OpenMeteoHourly: Decodable {
    let time: [String]
    let temperature2m: [Double]
    let relativeHumidity2m: [Double]?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
    }

    func points(timeZoneIdentifier: String?) -> [OpenMeteoHour] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current

        return time.enumerated().compactMap { index, rawTime in
            guard index < temperature2m.count, let date = formatter.date(from: rawTime) else { return nil }
            let humidity = relativeHumidity2m.flatMap { index < $0.count ? $0[index] : nil }
            return OpenMeteoHour(date: date, temperatureC: temperature2m[index], humidity: humidity)
        }
    }
}

private struct OpenMeteoHour {
    let date: Date
    let temperatureC: Double
    let humidity: Double?
}
#endif

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
