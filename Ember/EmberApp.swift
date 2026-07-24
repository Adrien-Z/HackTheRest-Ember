import SwiftUI
import BackgroundTasks

@main
struct EmberApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var health = HealthManager()
    @StateObject private var calendar = CalendarService()
    @StateObject private var wakeAlarm = WakeAlarmService()
    @StateObject private var sleepClimate = SleepClimateService()
    @StateObject private var auth = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase

    static let refreshTaskID = "com.bluebox.ember.planRefresh"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(health)
                .environmentObject(calendar)
                .environmentObject(wakeAlarm)
                .environmentObject(sleepClimate)
                .environmentObject(auth)
            .task(id: auth.isAuthenticated) {
                guard auth.isAuthenticated else { return }
                await health.autoConnect()
                await store.refresh(health: health, calendar: calendar)
                await sleepClimate.refreshIfAuthorized(store: store)
                await store.refreshBoxSpace()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background { EmberApp.scheduleBackgroundRefresh() }
            }
        }
        .backgroundTask(.appRefresh(EmberApp.refreshTaskID)) {
            // Chain the next opportunistic wake-up, then adapt the plan.
            await EmberApp.scheduleBackgroundRefresh()
            await store.backgroundPlanRefresh(calendar: calendar, wakeAlarm: wakeAlarm)
        }
    }

    /// Ask iOS for the next background slot. Timing is opportunistic — the
    /// system decides when (or whether) it runs, so this is best-effort.
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
