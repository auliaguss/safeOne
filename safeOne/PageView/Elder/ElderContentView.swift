//
//  ElderContentView.swift
//  safeOne
//

import SwiftUI

struct ElderContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "checklist") {
                ElderDashboard()
            }
            Tab("Profile", systemImage: "person") {
                ProfileView()
            }
        }
        .accentColor(.blue)
    }
}
#Preview {
    ElderContentView()
        .environmentObject(AppState())
}
