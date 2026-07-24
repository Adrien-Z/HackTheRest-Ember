import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Today", systemImage: "moon.stars.fill") }
            NavigationStack { ThermalView() }
                .tabItem { Label("Warm-Up", systemImage: "thermometer.sun.fill") }
            NavigationStack { CBTIView() }
                .tabItem { Label("Efficiency", systemImage: "bed.double.fill") }
            NavigationStack { CalendarView() }
                .tabItem { Label("Agenda", systemImage: "calendar") }
            NavigationStack { BoxSpaceView() }
                .tabItem { Label("Box Space", systemImage: "shippingbox.fill") }
        }
    }
}
