//
//  safeOneApp.swift
//  safeOne
//
//  Created by Aulia Agus on 20/05/26.
//

import SwiftUI

@main
struct safeOneApp: App {
    @Environment(\.scenePhase) var scenePhase

    // Inisialisasi AppState agar hidup selama aplikasi berjalan
    // Receives the regular push token via didRegisterForRemoteNotificationsWithDeviceToken
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appState = AppState()
    private let voipManager = VoIPManager.shared
    
    init() {
        _ = VoIPManager.shared
        NotificationManager.shared.setup()
        // Wire this synchronously (not in .onAppear) — a VoIP push can wake the app
        // and reach VoIPManager's PushKit/CallKit callbacks before SwiftUI has ever
        // rendered a view, so appState must already be set by the time that happens.
        VoIPManager.shared.appState = appState
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // ==========================================
                // LAYER 1: UI UTAMA APLIKASI
                // ==========================================
                // Onboarding sekarang bertindak sebagai Root View.
                // Di dalamnya sudah ada NavigationStack yang akan otomatis mengarahkan
                // user ke ContentView (Child) atau ElderContentView berdasarkan data di backend.
                Onboarding()
                    .environmentObject(appState)
                    .zIndex(0)
                
                // ==========================================
                // LAYER 2: FULL-SCREEN REMINDER (ELDER)
                // ==========================================
                // Covers everything when a reminder push notification fires.
                // Auto-reads the title via text-to-speech.
                if let reminder = appState.activeReminderAlert, appState.isElder {
                    ElderReminderFullScreenView(reminder: reminder)
                        .environmentObject(appState)
                        .background(Color.white.ignoresSafeArea())
                        .zIndex(998)
                        .transition(.opacity)
                }

                // ==========================================
                // LAYER 3: GLOBAL OVERLAY PANGGILAN MASUK
                // ==========================================
                // Karena ini diletakkan di level @main dengan zIndex tinggi,
                // layer ini dijamin akan menimpa seluruh layar (termasuk saat membuka Elder List).
                if let call = appState.incomingCall {
                    IncomingCallView(
                        callId: call.callId,
                        elderName: call.elderName,
                        channelName: call.channelName,
                        agoraToken: call.agoraToken,
                        agoraAppId: call.agoraAppId
                    )
                    .environmentObject(appState)
                    .background(Color.black.ignoresSafeArea()) // Menutup background belakang
                    .zIndex(999) // Memaksa layer berada di tingkat tertinggi absolut
                    .transition(.move(edge: .bottom)) // Animasi muncul dari bawah layar
                }
            }
            // Memberikan animasi halus saat layar panggilan masuk/keluar
            .animation(.easeInOut, value: appState.incomingCall != nil)
            .onAppear {
                // Hubungkan objek appState ke VoIPManager agar ketika payload push masuk,
                // data panggilan bisa langsung memperbarui state incomingCall secara global.
                voipManager.appState = appState
            }
//            .onChange(of: scenePhase) { phase in
//                if phase == .active {
//                    print("📱 App aktif — incomingCall: \(appState.incomingCall?.callId ?? "nil")")
//                    // Jika ada incomingCall dan belum di active call, berarti dijawab dari luar
//                    if appState.incomingCall != nil && !appState.inActiveCall {
//                        appState.isAnsweredFromCallKit = true
//                    }
//                }
//            }
        }
    }
}
