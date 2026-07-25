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

    @Published private(set) var rhythmData = WeatherRhythmData.fallback
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let openMeteoService: OpenMeteoService
    private let locationManager: LocationManager

    private init(
        openMeteoService: OpenMeteoService = .shared,
        locationManager: LocationManager = .shared
    ) {
        self.openMeteoService = openMeteoService
        self.locationManager = locationManager
    }

    func currentRhythm() -> WeatherRhythmData {
        rhythmData
    }

    func refreshWeather() async {
        print("🌤 refreshWeather called")

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            rhythmData = try await fetchRhythmData()
            print(
                    "🌅 Updated sunrise:",
                    rhythmData.sunriseHour,
                    "🌇 sunset:",
                    rhythmData.sunsetHour
            )
        } catch {
            print("❌ Weather error:", error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func fetchRhythmData() async throws -> WeatherRhythmData {
        let location = try await locationManager.currentLocation()

        print("🌤 Weather fetch started")
        let weather = try await openMeteoService.fetchWeather(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        print("🌅 Sunrise/sunset received")
        print("Sunrise:", weather.sunrise)
        print("Sunset:", weather.sunset)

        return WeatherRhythmData(
            sunriseHour: Self.decimalHour(from: weather.sunrise),
            sunsetHour: Self.decimalHour(from: weather.sunset),
            condition: weather.condition,
            temperature: weather.temperature
        )
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
