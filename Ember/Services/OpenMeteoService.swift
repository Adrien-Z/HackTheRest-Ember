//
//  OpenMeteoService.swift
//  Ember
//
//  Created by Ivy on 2026/7/25.
//

import Foundation

struct OpenMeteoWeatherData {
    let sunrise: Date
    let sunset: Date
    let temperature: Double?
    let condition: String
}

enum OpenMeteoServiceError: LocalizedError {
    case invalidURL
    case missingDailyWeather
    case invalidSunTime

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to build Open-Meteo forecast URL."
        case .missingDailyWeather:
            return "Open-Meteo did not return today's weather."
        case .invalidSunTime:
            return "Open-Meteo returned an invalid sunrise or sunset time."
        }
    }
}

final class OpenMeteoService {
    static let shared = OpenMeteoService()

    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWeather(latitude: Double, longitude: Double) async throws -> OpenMeteoWeatherData {
        guard var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            throw OpenMeteoServiceError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily", value: "sunrise,sunset,temperature_2m_max,weathercode"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components.url else {
            throw OpenMeteoServiceError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let forecast = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)

        guard
            let sunriseString = forecast.daily.sunrise.first,
            let sunsetString = forecast.daily.sunset.first
        else {
            throw OpenMeteoServiceError.missingDailyWeather
        }

        let timeZone = TimeZone(identifier: forecast.timezone) ?? .autoupdatingCurrent
        guard
            let sunrise = Self.parseLocalDate(sunriseString, timeZone: timeZone),
            let sunset = Self.parseLocalDate(sunsetString, timeZone: timeZone)
        else {
            throw OpenMeteoServiceError.invalidSunTime
        }

        return OpenMeteoWeatherData(
            sunrise: sunrise,
            sunset: sunset,
            temperature: forecast.daily.temperature2mMax.first,
            condition: Self.conditionDescription(for: forecast.daily.weatherCode.first)
        )
    }

    private static func parseLocalDate(_ string: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: string)
    }

    private static func conditionDescription(for weatherCode: Int?) -> String {
        switch weatherCode {
        case 0:
            return "Clear"
        case 1, 2, 3:
            return "Partly cloudy"
        case 45, 48:
            return "Fog"
        case 51, 53, 55, 56, 57:
            return "Drizzle"
        case 61, 63, 65, 66, 67:
            return "Rain"
        case 71, 73, 75, 77:
            return "Snow"
        case 80, 81, 82:
            return "Showers"
        case 85, 86:
            return "Snow showers"
        case 95, 96, 99:
            return "Thunderstorm"
        default:
            return "Unknown"
        }
    }
}

private struct OpenMeteoForecastResponse: Decodable {
    let timezone: String
    let daily: OpenMeteoDailyWeather
}

private struct OpenMeteoDailyWeather: Decodable {
    let sunrise: [String]
    let sunset: [String]
    let temperature2mMax: [Double]
    let weatherCode: [Int]

    private enum CodingKeys: String, CodingKey {
        case sunrise
        case sunset
        case temperature2mMax = "temperature_2m_max"
        case weatherCode = "weathercode"
    }
}
