import SwiftUI

// Shared preview environment so individual screens render in Xcode canvas.
#if DEBUG
extension DataStore {
    static var preview: DataStore { DataStore() }
}

#Preview("Home") {
    RootTabView()
        .environmentObject(DataStore.preview)
        .environmentObject(HealthManager())
        .environmentObject(CalendarService())
        .environmentObject(WakeAlarmService())
        .preferredColorScheme(.dark)
        .tint(Theme.ember)
}
#endif
