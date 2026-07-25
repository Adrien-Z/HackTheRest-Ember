import Foundation

struct SunSchedule {
    let sunrise: Date
    let sunset: Date
}

final class SunScheduleService {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func fetchSunSchedule(
        latitude: Double,
        longitude: Double
    ) async throws -> SunSchedule {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily", value: "sunrise,sunset"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            throw SunScheduleServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw SunScheduleServiceError.invalidResponse
        }

        let forecast = try decoder.decode(OpenMeteoForecastResponse.self, from: data)

        guard let sunriseText = forecast.daily.sunrise.first,
              let sunsetText = forecast.daily.sunset.first,
              let sunrise = Self.date(from: sunriseText),
              let sunset = Self.date(from: sunsetText) else {
            throw SunScheduleServiceError.missingSunSchedule
        }

        print("RAW sunrise:")
        print(sunriseText)
        print("RAW sunset:")
        print(sunsetText)
        print("Parsed sunrise:")
        print(sunrise)
        print("Parsed sunset:")
        print(sunset)
        print("[SunScheduleService] timezone used: \(Self.londonTimeZone.identifier)")

        return SunSchedule(sunrise: sunrise, sunset: sunset)
    }

    private static func date(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = londonTimeZone

        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }

        return nil
    }

    private static let londonTimeZone = TimeZone(identifier: "Europe/London") ?? TimeZone(secondsFromGMT: 0)!
}

private struct OpenMeteoForecastResponse: Decodable {
    let utcOffsetSeconds: Int
    let daily: Daily

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case daily
    }

    struct Daily: Decodable {
        let sunrise: [String]
        let sunset: [String]
    }
}

private enum SunScheduleServiceError: Error {
    case invalidURL
    case invalidResponse
    case missingSunSchedule
}
