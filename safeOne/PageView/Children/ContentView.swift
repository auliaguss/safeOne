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
