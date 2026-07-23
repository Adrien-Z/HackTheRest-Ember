import SwiftUI

@main
struct EmberApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var health = HealthManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(health)
                .preferredColorScheme(.dark)
                .tint(Theme.ember)
        }
    }
}
