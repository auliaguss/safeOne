//
//  AgoraManager.swift
//  safeOne
//
//  Created by Ivan Yuantama Pradipta on 03/06/26.
//



import AgoraRtcKit
import SwiftUI
import Combine

class AgoraManager: NSObject, ObservableObject {
    static let shared = AgoraManager()
    
    var agoraKit: AgoraRtcEngineKit?
    
    var pendingJoin: (token: String, channel: String, appId: String)?

    @Published var remoteUid: UInt? = nil        // UID lawan bicara
    @Published var isLocalAudioMuted = false
    @Published var isLocalVideoMuted = false
    
    override init() {
        super.init()
    }
    
    // MARK: - Setup Engine
    // MARK: - Setup Engine
    func setup(appId: String) {
        
        // 💡 1. MASUKKAN APP ID AGORA ASLI MILIKMU DI SINI (Di dalam tanda kutip)
        // Pastikan persis 32 karakter huruf kecil dan angka, tanpa spasi!
        let hardcodedAppID = "92a8aeae1db644dabe3cd77a614344dc"
        
        print("🔑 MENGHIDUPKAN AGORA DENGAN APP ID: '\(hardcodedAppID)'")
        print("📏 Panjang karakter App ID: \(hardcodedAppID.count)")
        
        // 2. Gunakan hardcodedAppID, BUKAN appId dari parameter
        let config = AgoraRtcEngineConfig()
        config.appId = hardcodedAppID
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        
        agoraKit?.enableVideo()
        agoraKit?.enableAudio()
        agoraKit?.setDefaultAudioRouteToSpeakerphone(true)
    }
    
    // MARK: - Join Channel
    func joinChannel(token: String, channelName: String, uid: UInt = 0) {
        guard let kit = agoraKit else { return }
        
        let option = AgoraRtcChannelMediaOptions()
        option.clientRoleType = .broadcaster
        option.channelProfile = .communication
        
        // Simpan hasil eksekusinya ke dalam variabel 'result'
        let result = kit.joinChannel(
            byToken: token.isEmpty ? nil : token,
            channelId: channelName,
            uid: uid,
            mediaOptions: option
        ) { channel, uid, elapsed in
            print("✅ Joined channel: \(channel), uid: \(uid)")
        }
        
        // Cek apakah langsung ditolak oleh SDK
        print("🚀 Status Eksekusi Join Agora: \(result)")
        if result != 0 {
            print("❌ GAGAL MASUK ROOM! Token Ditolak. Kode Error Agora: \(result)")
        }
    }
    
    // MARK: - Leave Channel
    func leaveChannel() {
        agoraKit?.leaveChannel { stats in
            print("👋 Left channel, duration: \(stats.duration)s")
        }
        remoteUid = nil
    }
    
    // MARK: - Setup Local Video
    func setupLocalVideo(view: UIView) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = 0
        canvas.renderMode = .hidden
        canvas.view = view
        agoraKit?.setupLocalVideo(canvas)
        agoraKit?.startPreview()
    }
    
    // MARK: - Setup Remote Video
    func setupRemoteVideo(uid: UInt, view: UIView) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = uid
        canvas.renderMode = .hidden
        canvas.view = view
        agoraKit?.setupRemoteVideo(canvas)
    }
    
    // MARK: - Toggle Audio/Video
    func toggleAudio() {
        isLocalAudioMuted.toggle()
        agoraKit?.muteLocalAudioStream(isLocalAudioMuted)
    }
    
    func toggleVideo() {
        isLocalVideoMuted.toggle()
        agoraKit?.muteLocalVideoStream(isLocalVideoMuted)
    }
    

    func joinWhenReady(token: String, channelName: String, appId: String) {
        pendingJoin = (token, channelName, appId)
        // Jika audio sudah aktif (misal user buka app langsung), langsung join
        // Kalau tidak, tunggu didActivate dari CallKit
    }

    func executePendingJoin() {
        guard let pending = pendingJoin else { return }
        setup(appId: pending.appId)
        joinChannel(token: pending.token, channelName: pending.channel)
        pendingJoin = nil
    }
}

// MARK: - Delegate
extension AgoraManager: AgoraRtcEngineDelegate {
    // Remote user joined
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        DispatchQueue.main.async {
            self.remoteUid = uid
            print("👤 Remote user joined: \(uid)")
        }
    }
    
    // Remote user left
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        DispatchQueue.main.async {
            self.remoteUid = nil
            print("👤 Remote user left: \(uid)")
        }
    }
    
    // Local user joined
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("🎙️ Local joined channel: \(channel)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("❌ Agora error: \(errorCode.rawValue)")
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioRouteChanged routing: AgoraAudioOutputRouting) {
        print("🔊 Audio route changed: \(routing.rawValue)")
    }
}
