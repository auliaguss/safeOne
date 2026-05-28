//
//  ContentView.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "checklist")
                }
                .tag(0)

            ReminderListView()
                .tabItem {
                    Label("Reminder", systemImage: "bell")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}
#Preview {
    ContentView()
        .environmentObject(AppState())
}
