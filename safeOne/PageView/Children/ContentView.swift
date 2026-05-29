//
//  ContentView.swift
//  safeOne
//
//
//  Created by Aulia Agus on 20/05/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

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
