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
    private var pendingCallData: IncomingCallData?
    private var pendingAnswerAction: CXAnswerCallAction?
    private var pendingVoipToken: String? = nil  // ← tambah ini

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
    
    func reportCallEnded() {
        guard let uuid = currentCallUUID else { return }
        callKitProvider?.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
        currentCallUUID = nil
    }
    
    func setupPushKit() {
        pushRegistry = PKPushRegistry(queue: DispatchQueue.main)
        pushRegistry?.delegate = self
        pushRegistry?.desiredPushTypes = [.voIP]
    }
    
    // ← Dipanggil dari AppState.saveSession setelah login
    func flushPendingVoipToken() async {
        print("🔄 flushPendingVoipToken — pendingVoipToken: \(pendingVoipToken ?? "nil")")
        guard let token = pendingVoipToken,
              let jwtToken = appState?.token else {
            print("⚠️ flush gagal — token: \(pendingVoipToken ?? "nil"), jwt: \(appState?.token != nil)")
            return
        }
        pendingVoipToken = nil
        await sendVoipTokenToBackend(token: token, jwtToken: jwtToken)
    }

    private func sendVoipTokenToBackend(token: String) async {
        guard let appState = self.appState,
              let jwtToken = appState.token else {
            print("⏳ Menunggu user login untuk menyimpan token VoIP...")
            pendingVoipToken = token  // ← simpan dulu
            return
        }
        await sendVoipTokenToBackend(token: token, jwtToken: jwtToken)
    }
    
    private func sendVoipTokenToBackend(token: String, jwtToken: String) async {
        guard let url = URL(string: "\(AppConfig.baseURL)/auth/apns-token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["apnsToken": token]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("📡 VoIP token response: \(http.statusCode)")
                if http.statusCode == 200 {
                    print("✅ VoIP Token sukses disimpan ke Database Backend!")
                } else if http.statusCode == 401 {
                    print("⚠️ JWT invalid, simpan untuk retry setelah login")
                    pendingVoipToken = token  // ← tambah ini
                } else {
                    print("❌ Gagal menyimpan VoIP Token. Status: \(http.statusCode)")
                }
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
            // Apple requires reportNewIncomingCall for every VoIP push we receive, even
            // ones we can't use — skipping it risks iOS throttling/blocking future VoIP
            // pushes to this app. Report a generic call, then immediately end it.
            let fallbackUUID = UUID()
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: "Emergency Call")
            callKitProvider?.reportNewIncomingCall(with: fallbackUUID, update: update) { [weak self] _ in
                self?.callKitProvider?.reportCall(with: fallbackUUID, endedAt: Date(), reason: .failed)
                completion()
            }
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
            self.pendingCallData = callData
            appState.incomingCall = callData
            appState.stopPolling()
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
        print("🔊 didActivate — waktu: \(Date())")
        print("🔊 CallKit: Audio Session Diaktifkan")
        DispatchQueue.main.async {
            AgoraManager.shared.executePendingJoin()
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("🔇 CallKit: Audio Session Dimatikan")
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("📲 User answer dari CallKit — buka layar Terima/Tolak")
        
        DispatchQueue.main.async {
            guard let appState = self.appState else { return }
            if appState.incomingCall == nil, let pending = self.pendingCallData {
                appState.incomingCall = pending
                appState.stopPolling()
            }
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("📴 Panggilan diakhiri dari CallKit")
        AgoraManager.shared.leaveChannel()

        // Fall back to the push-delivered pendingCallData's callId when appState.incomingCall
        // hasn't been set yet (e.g. user declines from the lock screen before the push
        // handler's main-queue hop has landed) — otherwise the backend is never told the
        // call was declined/ended, and the caller keeps waiting.
        guard let appState = self.appState,
              let token = appState.token,
              let callId = appState.incomingCall?.callId ?? pendingCallData?.callId else {
            self.pendingCallData = nil
            action.fulfill()
            return
        }

        Task {
            let roleEndpoint = appState.inActiveCall ? "end" : "decline"
            if let url = URL(string: "\(AppConfig.baseURL)/calls/\(callId)/\(roleEndpoint)") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }

            await MainActor.run {
                appState.inActiveCall = false
                appState.incomingCall = nil
                self.pendingCallData = nil
                action.fulfill()
            }
        }
    }
}
