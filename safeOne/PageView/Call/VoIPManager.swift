import Foundation
import PushKit
import CallKit
import SwiftUI
import AVFoundation

class VoIPManager: NSObject {
    static let shared = VoIPManager()
    
    private var pushRegistry: PKPushRegistry?
    private var callKitProvider: CXProvider?
    private var callKitController = CXCallController()
    
    var appState: AppState?
    private var currentCallUUID: UUID?
    private var pendingCallData: IncomingCallData?  // ← tambah ini

    
    override init() {
        super.init()
        setupCallKit()
        setupPushKit()
    }
    
    private func setupCallKit() {
        let configuration = CXProviderConfiguration(localizedName: "SafeOne+")
        configuration.supportsVideo = true
        configuration.maximumCallGroups = 1
        configuration.supportedHandleTypes = [.generic]
        
        callKitProvider = CXProvider(configuration: configuration)
        callKitProvider?.setDelegate(self, queue: nil)
    }
    
    func clearPendingCall() {
        pendingCallData = nil
    }
    
    func setupPushKit() {
        pushRegistry = PKPushRegistry(queue: DispatchQueue.main)
        pushRegistry?.delegate = self
        pushRegistry?.desiredPushTypes = [.voIP]
    }
    
    private func sendVoipTokenToBackend(token: String) async {
        guard let appState = self.appState,
              let jwtToken = appState.token else {
            print("⏳ Menunggu user login untuk menyimpan token VoIP...")
            return
        }
        
        guard let url = URL(string: "\(AppConfig.baseURL)/auth/apns-token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["apnsToken": token]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                print("✅ VoIP Token sukses disimpan ke Database Backend!")
            } else {
                print("❌ Gagal menyimpan VoIP Token ke Backend.")
            }
        } catch {
            print("❌ Error jaringan saat menyimpan VoIP Token: \(error)")
        }
    }
}

// MARK: - PKPushRegistryDelegate
extension VoIPManager: PKPushRegistryDelegate {
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let tokenParts = pushCredentials.token.map { String(format: "%02.2hhx", $0) }
        let voipToken = tokenParts.joined()
        print("🔑 Token PushKit VoIP: \(voipToken)")
        Task { await sendVoipTokenToBackend(token: voipToken) }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        
        guard let customData = payload.dictionaryPayload as? [String: Any],
              let callId = customData["callId"] as? String,
              let elderName = customData["elderName"] as? String,
              let channelName = customData["channelName"] as? String,
              let agoraAppId = customData["agoraAppId"] as? String else {
            completion()
            return
        }
        
        let uuid = UUID()
        self.currentCallUUID = uuid
        
        let callData = IncomingCallData(
                callId: callId,
                elderName: elderName,
                channelName: channelName,
                agoraToken: "",
                agoraAppId: agoraAppId
            )
            self.pendingCallData = callData
        
        DispatchQueue.main.async {
            guard let appState = self.appState else { return }
            appState.incomingCall = IncomingCallData(
                callId: callId,
                elderName: elderName,
                channelName: channelName,
                agoraToken: "",
                agoraAppId: agoraAppId
            )
            self.pendingCallData = callData      // ← simpan backup
            appState.incomingCall = callData
            appState.stopPolling()  // ← stop polling saat push masuk
        }
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: elderName)
        update.hasVideo = true
        
        callKitProvider?.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("❌ Gagal memunculkan CallKit: \(error.localizedDescription)")
            }
            completion()
        }
    }
}

// MARK: - CXProviderDelegate
extension VoIPManager: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        AgoraManager.shared.leaveChannel()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("🔊 CallKit: Audio Session Diaktifkan")
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("🔇 CallKit: Audio Session Dimatikan")
    }
    
    // User answer dari CallKit → fulfill langsung, app terbuka, user lihat IncomingCallView
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("📲 User answer dari CallKit — buka layar Terima/Tolak")
        
        DispatchQueue.main.async {
                guard let appState = self.appState else { return }
                
                // Jika incomingCall sudah nil (kena clear), restore dari backup
                if appState.incomingCall == nil, let pending = self.pendingCallData {
                    appState.incomingCall = pending
                    appState.stopPolling()
                }
            }
        
        action.fulfill()
    }
    
    // User tolak/akhiri dari CallKit
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("📴 Panggilan diakhiri dari CallKit")
        AgoraManager.shared.leaveChannel()
        
        guard let appState = self.appState, let incomingCall = appState.incomingCall else {
            self.pendingCallData = nil  // ← clear
            action.fulfill()
            return
        }
        
        Task {
            let roleEndpoint = appState.inActiveCall ? "end" : "decline"
            if let token = appState.token,
               let url = URL(string: "\(AppConfig.baseURL)/calls/\(incomingCall.callId)/\(roleEndpoint)") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }
            
            await MainActor.run {
                appState.inActiveCall = false
                appState.incomingCall = nil
                self.pendingCallData = nil  // ← clear backup
                action.fulfill()
            }
        }
    }
}
