import SwiftUI
import BackgroundTasks

@main
struct EmberApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var health = HealthManager()
    @StateObject private var calendar = CalendarService()
    @StateObject private var wakeAlarm = WakeAlarmService()
    @Environment(\.scenePhase) private var scenePhase

    static let refreshTaskID = "com.bluebox.ember.planRefresh"

    @State private var showSplash = true
    @State private var appRevealed = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    .environmentObject(store)
                    .environmentObject(health)
                    .environmentObject(calendar)
                    .environmentObject(wakeAlarm)
                    .scaleEffect(appRevealed ? 1 : 0.88)
                if showSplash {
                    SplashView(onReveal: {
                        // The flaps have started unfolding — zoom the app in.
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                            appRevealed = true
                        }
                    }, onFinished: {
                        withAnimation(.easeOut(duration: 0.25)) { showSplash = false }
                    })
                    .zIndex(1)
                    .transition(.opacity)
                }
            }
            .preferredColorScheme(.dark)
            .tint(Theme.ember)
            .task {
                await health.autoConnect()
                await store.refresh(health: health, calendar: calendar)
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
