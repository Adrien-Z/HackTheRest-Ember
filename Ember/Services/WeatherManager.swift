//
//  WeatherManager.swift
//  Ember
//
//  Created by Ivy on 2026/7/25.
//

import Combine
import CoreLocation
import Foundation

struct WeatherRhythmData {
    let sunriseHour: Double
    let sunsetHour: Double
    let condition: String
    let temperature: Double?
}

enum WeatherManagerError: LocalizedError {
    case sunScheduleUnavailable

    var errorDescription: String? {
        switch self {
        case .sunScheduleUnavailable:
            return "Today's sunrise and sunset are unavailable."
        }
    }
}

@MainActor
final class WeatherManager: ObservableObject {
    static let shared = WeatherManager()

    @Published private(set) var rhythmData: WeatherRhythmData?
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published private(set) var errorMessage: String?

    private let openMeteoService: OpenMeteoService
    private let locationManager: LocationManager
    private let cacheStore: CachedRhythmStore
    private var cachedSnapshot: CachedRhythmSnapshot?

    private init() {
        self.openMeteoService = .shared
        self.locationManager = .shared
        self.cacheStore = .shared

        if let snapshot = self.cacheStore.load() {
            cachedSnapshot = snapshot
            rhythmData = snapshot.rhythmData
        }

        Task {
            await refreshWeather()
        }
    }

    func currentRhythm() -> WeatherRhythmData {
        rhythmData ?? .fallback
    }

    func refreshWeather() async {
        guard !isUpdating else {
            return
        }

        print("🌤 refreshWeather called")

        isLoading = rhythmData == nil
        isUpdating = true
        errorMessage = nil

        defer {
            isLoading = false
            isUpdating = false
        }

        do {
            let updatedRhythm = try await fetchRhythmData()
            rhythmData = updatedRhythm.data
            cacheStore.save(
                rhythmData: updatedRhythm.data,
                latitude: updatedRhythm.location.coordinate.latitude,
                longitude: updatedRhythm.location.coordinate.longitude
            )
            cachedSnapshot = cacheStore.load()
            print(
                    "🌅 Updated sunrise:",
                    updatedRhythm.data.sunriseHour,
                    "🌇 sunset:",
                    updatedRhythm.data.sunsetHour
            )
        } catch {
            print("❌ Weather error:", error.localizedDescription)
            errorMessage = error.localizedDescription
            if rhythmData == nil {
                rhythmData = .fallback
            }
        }
    }

    private func fetchRhythmData() async throws -> (data: WeatherRhythmData, location: CLLocation) {
        let location = try await locationManager.currentLocation()
        logCacheDistanceIfNeeded(for: location)

        print("🌤 weather fetch started")
        let weather = try await openMeteoService.fetchWeather(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        print("🌅 Sunrise/sunset received")
        print("Sunrise:", weather.sunrise)
        print("Sunset:", weather.sunset)

        let data = WeatherRhythmData(
            sunriseHour: Self.decimalHour(from: weather.sunrise),
            sunsetHour: Self.decimalHour(from: weather.sunset),
            condition: weather.condition,
            temperature: weather.temperature
        )

        return (data, location)
    }

    private func logCacheDistanceIfNeeded(for location: CLLocation) {
        guard let cachedSnapshot else {
            return
        }

        let distance = cachedSnapshot.distance(from: location)
        if distance < 10_000 {
            print("🌤 Cached rhythm location is close; refreshing silently.")
        } else {
            print("🌤 Location changed significantly; refreshing rhythm data.")
        }
    }

    private static func decimalHour(from date: Date) -> Double {
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        return hour + minute / 60
    }
}

private extension WeatherRhythmData {
    static let fallback = WeatherRhythmData(
        sunriseHour: 5.14,
        sunsetHour: 21.0,
        condition: "Unavailable",
        temperature: nil
    )
}
