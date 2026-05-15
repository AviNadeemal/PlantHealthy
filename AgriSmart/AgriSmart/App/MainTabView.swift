import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var alertVM = AlertViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            CropLogListView()
                .tabItem {
                    Label("Crops", systemImage: "leaf.fill")
                }
                .tag(1)

            AlertsCenterView()
                .tabItem {
                    Label("Alerts", systemImage: "bell.fill")
                }
                .badge(alertVM.unreadCount)
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(.agriGreen)
        .environmentObject(alertVM)
    }
}
