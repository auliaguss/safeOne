import SwiftUI

@main
struct safeOneApp: App {
    @StateObject private var appState = AppState()
    private let voipManager = VoIPManager.shared

    init() {
        _ = VoIPManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // MARK: - Root View (driven by login state)
                Group {
                    if appState.isLoggedIn {
                        if appState.isElder {
                            ElderContentView()
                        } else {
                            ContentView()
                        }
                    } else {
                        Onboarding()
                    }
                }
                .transition(.opacity)
                .zIndex(0)

                // MARK: - Global Incoming Call Overlay
                if let call = appState.incomingCall {
                    IncomingCallView(
                        callId: call.callId,
                        elderName: call.elderName,
                        channelName: call.channelName,
                        agoraToken: call.agoraToken,
                        agoraAppId: call.agoraAppId
                    )
                    .environmentObject(appState)
                    .background(Color.black.ignoresSafeArea())
                    .zIndex(999)
                    .transition(.move(edge: .bottom))
                }
            }
            .environmentObject(appState)
            .animation(.easeInOut, value: appState.isLoggedIn)
            .animation(.easeInOut, value: appState.incomingCall != nil)
            .onAppear {
                voipManager.appState = appState
            }
        }
    }
}
