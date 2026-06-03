import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "checklist") {
                DashboardView()
            }
            Tab("Reminder", systemImage: "bell") {
                ReminderListView()
            }
            Tab("Profile", systemImage: "person") {
                ProfileView()
            }
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
