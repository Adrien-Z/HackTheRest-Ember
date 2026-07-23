import SwiftUI

@main
struct EmberApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var health = HealthManager()
    @StateObject private var calendar = CalendarService()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(health)
                .environmentObject(calendar)
                .preferredColorScheme(.dark)
                .tint(Theme.ember)
                .task { await store.refresh(health: health, calendar: calendar) }
        }
    }
}
