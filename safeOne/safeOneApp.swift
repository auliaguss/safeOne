import SwiftUI

@main
struct safeOneApp: App {
    // Inisialisasi AppState agar hidup selama aplikasi berjalan
    @StateObject private var appState = AppState()
    
    // Inisialisasi instance VoIPManager agar PushKit & CallKit aktif sejak awal aplikasi terbuka
    private let voipManager = VoIPManager.shared
    
    init() {
        _ = VoIPManager.shared
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
                // LAYER 2: GLOBAL OVERLAY PANGGILAN MASUK
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
        }
    }
}
