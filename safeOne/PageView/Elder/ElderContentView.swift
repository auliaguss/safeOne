//
//  ElderContentView.swift
//  safeOne
//

import SwiftUI

struct ElderContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.elderTabSelection) {
            Tab("Dashboard", systemImage: "checklist", value: ElderTab.dashboard) {
                ElderDashboard()
            }
            Tab("Profile", systemImage: "person", value: ElderTab.profile) {
                ElderProfileView()
            }
        }
        .accentColor(.blue)
        .navigationBarBackButtonHidden(true)
    }
}
#Preview {
    ElderContentView()
        .environmentObject(AppState())
}
