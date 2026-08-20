//
//  ContentView.swift
//  safeOne
//
//  Created by Aulia Agus on 20/05/26.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.childTabSelection) {
            Tab("Dashboard", systemImage: "checklist", value: ChildTab.dashboard) {
                DashboardView()
            }
            Tab("Reminder", systemImage: "bell", value: ChildTab.reminders) {
                ReminderListView()
            }
            Tab("Profile", systemImage: "person", value: ChildTab.profile) {
                ProfileView()
            }
        }
        .accentColor(.blue)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Request Izin Kamera & Mic saat masuk ke main menu
            AVAudioApplication.requestRecordPermission { _ in }
            AVCaptureDevice.requestAccess(for: .video) { _ in }
            
            // 🔥 Jalankan polling global dari AppState
            appState.startPolling()
        }
        .onDisappear {
            // Matikan polling jika keluar dari ContentView
            appState.stopPolling()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
