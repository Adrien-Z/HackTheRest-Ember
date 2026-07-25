import Foundation
import SwiftUI

@MainActor
final class DailyRhythmViewModel: ObservableObject {
    @Published var sunrise: Date?
    @Published var sunset: Date?
    @Published var isLoading: Bool = false

    private let service: SunScheduleService
    private let latitude = 51.5074
    private let longitude = -0.1278

    init(service: SunScheduleService = SunScheduleService()) {
        self.service = service
        self.sunrise = Self.fallbackDate(hour: 7, minute: 2)
        self.sunset = Self.fallbackDate(hour: 18, minute: 30)
    }

    func fetchSunSchedule() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let schedule = try await service.fetchSunSchedule(
                latitude: latitude,
                longitude: longitude)
            sunrise = schedule.sunrise
            sunset = schedule.sunset
        } catch {
            sunrise = sunrise ?? Self.fallbackDate(hour: 7, minute: 2)
            sunset = sunset ?? Self.fallbackDate(hour: 18, minute: 30)
        }
    }

    private static func fallbackDate(hour: Int, minute: Int) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)
    }
}
