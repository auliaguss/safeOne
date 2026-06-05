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
