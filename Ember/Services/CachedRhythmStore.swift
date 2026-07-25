//
//  CachedRhythmStore.swift
//  Ember
//
//  Created by Ivy on 2026/7/25.
//

import CoreLocation
import Foundation

struct CachedRhythmSnapshot: Codable {
    let sunriseHour: Double
    let sunsetHour: Double
    let condition: String
    let temperature: Double?
    let latitude: Double
    let longitude: Double
    let lastUpdated: Date

    var rhythmData: WeatherRhythmData {
        WeatherRhythmData(
            sunriseHour: sunriseHour,
            sunsetHour: sunsetHour,
            condition: condition,
            temperature: temperature
        )
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude).distance(from: location)
    }
}

final class CachedRhythmStore {
    static let shared = CachedRhythmStore()

    private let defaults: UserDefaults
    private let key = "cachedRhythmSnapshot"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CachedRhythmSnapshot? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(CachedRhythmSnapshot.self, from: data)
    }

    func save(
        rhythmData: WeatherRhythmData,
        latitude: Double,
        longitude: Double,
        lastUpdated: Date = Date()
    ) {
        let snapshot = CachedRhythmSnapshot(
            sunriseHour: rhythmData.sunriseHour,
            sunsetHour: rhythmData.sunsetHour,
            condition: rhythmData.condition,
            temperature: rhythmData.temperature,
            latitude: latitude,
            longitude: longitude,
            lastUpdated: lastUpdated
        )

        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
