import Foundation
import PushKit
import CallKit
import SwiftUI
import AVFoundation
import Combine
import AgoraRtcKit

class VoIPManager: NSObject, ObservableObject {
    static let shared = VoIPManager()
    
    @Published var isAnsweredFromCallKit = false
    
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
            // Beri tahu Agora SDK bahwa audio session sudah aktif dari CallKit
            AgoraManager.shared.agoraKit?.setAudioSessionOperationRestriction(.all)
            AgoraManager.shared.executePendingJoin()
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("🔇 CallKit: Audio Session Dimatikan")
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("📲 User answer dari CallKit — buka layar Terima/Tolak")
        
        DispatchQueue.main.async {
            guard let appState = self.appState else {
                action.fulfill()
                return
            }
            if appState.incomingCall == nil, let pending = self.pendingCallData {
                appState.incomingCall = pending
                appState.stopPolling()
            }
            
            guard let callData = appState.incomingCall ?? self.pendingCallData else {
                action.fulfill()
                return
            }
            
            // Tandai bahwa call dijawab dari CallKit
            self.isAnsweredFromCallKit = true
            appState.inActiveCall = true
            
            // Panggil backend /answer untuk mendapatkan Agora token,
            // lalu setup pendingJoin agar didActivate bisa langsung join channel
            Task {
                await self.answerAndPrepareAgora(callData: callData, appState: appState)
                action.fulfill()
            }
        }
        
        
    }
    
    /// Panggil backend /answer dan siapkan Agora untuk join saat didActivate
    private func answerAndPrepareAgora(callData: IncomingCallData, appState: AppState) async {
        guard let token = appState.token,
              let url = URL(string: "\(AppConfig.baseURL)/calls/\(callData.callId)/answer")
        else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let agoraToken = json["agoraToken"] as? String else {
                print("❌ Gagal mendapatkan Agora token dari /answer")
                return
            }
            
            await MainActor.run {
                // Setup Agora engine dan simpan sebagai pending join
                // didActivate dari CallKit akan memanggil executePendingJoin()
                AgoraManager.shared.setup(appId: callData.agoraAppId)
                AgoraManager.shared.joinWhenReady(
                    token: agoraToken,
                    channelName: callData.channelName,
                    appId: callData.agoraAppId
                )
                print("✅ Agora siap — menunggu didActivate dari CallKit")
            }
        } catch {
            print("❌ Error saat answer call dari CallKit: \(error)")
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("📴 Panggilan diakhiri dari CallKit")
        AgoraManager.shared.leaveChannel()
        
        guard let appState = self.appState, let incomingCall = appState.incomingCall else {
            self.pendingCallData = nil
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
                self.pendingCallData = nil
                action.fulfill()
            }
        }
    }
}

