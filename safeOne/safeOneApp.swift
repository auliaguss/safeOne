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
    @StateObject private var tutorialManager = TutorialManager()
    private let voipManager = VoIPManager.shared
    
    init() {
        _ = VoIPManager.shared
        NotificationManager.shared.setup()
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
                    .environmentObject(tutorialManager)
                    .zIndex(0)
                    // The tutorial overlay blocks all touches on the real UI anyway;
                    // hide it from VoiceOver too so swipe navigation can't wander into it.
                    .accessibilityHidden(tutorialManager.isActive)

                // ==========================================
                // LAYER 1B: ONBOARDING TUTORIAL (COACHMARK)
                // ==========================================
                // Sits above the real UI but below the reminder/call overlays —
                // an incoming emergency call must always be able to interrupt it.
                if tutorialManager.isActive {
                    TutorialOverlayView()
                        .environmentObject(appState)
                        .environmentObject(tutorialManager)
                        .zIndex(1)
                        .transition(.opacity)
                }

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
            .animation(.easeInOut, value: tutorialManager.isActive)
            .onPreferenceChange(TutorialAnchorPreferenceKey.self) { anchors in
                tutorialManager.anchors = anchors
            }
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
