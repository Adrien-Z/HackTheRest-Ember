import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Today", systemImage: "moon.stars.fill") }
            NavigationStack { AgendaView() }
                .tabItem { Label("Agenda", systemImage: "calendar") }
            NavigationStack { RestLabView() }
                .tabItem { Label("Rest Lab", systemImage: "sparkles") }
            NavigationStack { BoxSpaceView() }
                .tabItem { Label("Box Space", systemImage: "shippingbox.fill") }
        }
    }
}
