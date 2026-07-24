import SwiftUI

// Shared preview environment so individual screens render in Xcode canvas.
#if DEBUG
extension DataStore {
    static var preview: DataStore { DataStore() }
}

struct EmberRootPreview: PreviewProvider {
    static var previews: some View {
        RootTabView()
            .environmentObject(DataStore.preview)
            .environmentObject(HealthManager())
            .environmentObject(CalendarService())
            .environmentObject(WakeAlarmService())
            .preferredColorScheme(.dark)
            .tint(Theme.ember)
            .previewDisplayName("Home")
    }
}
#endif
