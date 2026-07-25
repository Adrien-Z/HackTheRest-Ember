import SwiftUI

struct RootTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Today", systemImage: "moon.stars.fill") }
                .tag(0)
            NavigationStack { AgendaView() }
                .tabItem { Label("Agenda", systemImage: "calendar") }
                .tag(1)
            NavigationStack { RestLabView() }
                .tabItem { Label("Rest Lab", systemImage: "sparkles") }
                .tag(2)
            NavigationStack { BoxSpaceView() }
                .tabItem { Label("Box Space", systemImage: "shippingbox.fill") }
                .tag(3)
        }
        .onChange(of: selectedTab) { _ in Haptics.tick() }
    }
}
