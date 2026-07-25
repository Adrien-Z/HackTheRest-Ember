import SwiftUI

struct SunScheduleDebugView: View {
    @State private var sunSchedule: SunSchedule?
    @State private var errorMessage: String?
    @State private var isLoading = false

    private let service = SunScheduleService()
    private let latitude = 51.5074
    private let longitude = -0.1278

    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let sunSchedule {
                VStack(spacing: 8) {
                    Text("Sunrise:")
                    Text(Self.timeFormatter.string(from: sunSchedule.sunrise))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))

                    Text("Sunset:")
                        .padding(.top, 8)
                    Text(Self.timeFormatter.string(from: sunSchedule.sunset))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red.opacity(0.85))
            }
        }
        .foregroundStyle(.white)
        .padding()
        .task {
            await fetchSunSchedule()
        }
    }

    private func fetchSunSchedule() async {
        isLoading = true
        defer { isLoading = false }

        do {
            sunSchedule = try await service.fetchSunSchedule(
                latitude: latitude,
                longitude: longitude)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = .current
        return formatter
    }()
}

struct SunScheduleDebugView_Previews: PreviewProvider {
    static var previews: some View {
        SunScheduleDebugView()
            .background(NightBackground())
            .preferredColorScheme(.dark)
    }
}
