//
//  ElderContentView.swift
//  safeOne
//

import SwiftUI

struct ElderContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.elderTabSelection) {
            Tab(appState.text("Beranda", "Dashboard"), systemImage: "checklist", value: ElderTab.dashboard) {
                ElderDashboard()
            }
            Tab(appState.text("Profil", "Profile"), systemImage: "person", value: ElderTab.profile) {
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
