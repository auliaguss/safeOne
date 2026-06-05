//
//  IncomingCallView.swift
//  safeOne
//

import SwiftUI
import Combine
import AVFoundation

struct IncomingCallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject private var agoraManager = AgoraManager.shared
    

    let callId: String
    let elderName: String
    let channelName: String
    let agoraToken: String
    let agoraAppId: String

    @State private var isConnected = false
    @State private var callDuration = 0
    @State private var showSOS = false
    @State private var hasRemoteUserJoined = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if !isConnected {
                // ── Layar Incoming Call ──
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 6) {
                        Text("Emergency Call")
                            .font(.system(size: 28, weight: .bold))
                        Text(elderName)
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }

                    Spacer().frame(height: 48)

                    ZStack {
                        Circle()
                            .fill(Color(red: 0.87, green: 0.95, blue: 1.0))
                            .frame(width: 200, height: 200)
                        Image(systemName: "person.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    HStack(spacing: 60) {
                        VStack(spacing: 8) {
                            Button { Task { await declineCall() } } label: {
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white)
                                    .frame(width: 72, height: 72)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                            Text("Tolak").font(.caption).foregroundColor(.secondary)
                        }

                        VStack(spacing: 8) {
                            Button {
                                print("🔴 TOMBOL TERIMA DITEKAN")
                                Task { await acceptCall() }
                            } label: {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white)
                                    .frame(width: 72, height: 72)
                                    .background(Color.green)
                                    .clipShape(Circle())
                            }
                            Text("Terima").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 60)
                }

            } else {
                // ── Layar Video Call Aktif ──
                if let remoteUid = agoraManager.remoteUid {
                    VideoView(uid: remoteUid, agoraManager: agoraManager)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                    Text("Menunggu video elder...")
                        .foregroundColor(.white)
                }

                VStack {
                    HStack {
                        Spacer()
                        VideoView(uid: 0, agoraManager: agoraManager)
                            .frame(width: 100, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 1))
                            .padding(.top, 60)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }

                VStack {
                    Spacer()

                    Text(formatTime(callDuration))
                        .foregroundColor(.white)
                        .font(.system(size: 16, design: .rounded))
                        .padding(.bottom, 12)

                    HStack(spacing: 32) {
                        Button { agoraManager.toggleAudio() } label: {
                            Image(systemName: agoraManager.isLocalAudioMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }

                        Button { Task { await endCall() } } label: {
                            Image(systemName: "phone.down.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 72, height: 72)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        
                        Spacer().frame(width: 56, height: 56)
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .sheet(isPresented: $showSOS) {
            SOSContactsView()
        }
        .onDisappear {
            agoraManager.leaveChannel()
        }
        .onReceive(timer) { _ in
            if isConnected {
                callDuration += 1

                // Polling setiap 3 detik — deteksi jika elder end call
                if callDuration % 3 == 0 {
                    Task { await checkCallStatus() }
                }

                // Failsafe: tutup jika elder tidak muncul dalam 30 detik
                if callDuration > 30 && agoraManager.remoteUid == nil {
                    print("⏱️ Auto-hangup: Elder tidak ditemukan.")
                    Task { await endCall() }
                }
            }
        }
        
        .onChange(of: agoraManager.remoteUid) { newUid in
            if newUid != nil {
                hasRemoteUserJoined = true
            } else if newUid == nil && hasRemoteUserJoined {
                Task { await endCall() }
            }
        }
        
//        .onAppear {
//            if appState.isAnsweredFromCallKit {
//                appState.isAnsweredFromCallKit = false
//                Task { await acceptCall() }
//            }
//        }
        
    }

    // MARK: - Accept
    private func acceptCall() async {
        print("📞 acceptCall() dipanggil — waktu: \(Date())")

        // Set TRUE paling awal — polling tidak akan nil-kan incomingCall selagi ini true
        await MainActor.run { appState.inActiveCall = true }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 detik

        
        guard let token = appState.token,
              let url = URL(string: "\(AppConfig.baseURL)/calls/\(callId)/answer")
        else {
            await MainActor.run { appState.inActiveCall = false }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let receivedToken = json["agoraToken"] as? String else {
                await MainActor.run {
                    appState.inActiveCall = false
                    appState.incomingCall = nil
                }
                return
            }

            await MainActor.run {
                agoraManager.setup(appId: agoraAppId)
                
                try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetooth, .defaultToSpeaker])
                    try? AVAudioSession.sharedInstance().setActive(true)
                
                agoraManager.joinChannel(token: receivedToken, channelName: channelName)
                withAnimation { isConnected = true }
            }
        } catch {
            await MainActor.run { appState.inActiveCall = false }
        }
    }

    // MARK: - Decline
    private func declineCall() async {
        VoIPManager.shared.reportCallEnded()  // ← tambah ini
        guard let token = appState.token else { return }
        guard let url = URL(string: "\(AppConfig.baseURL)/calls/\(callId)/decline") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)

        await MainActor.run {
            appState.inActiveCall = false
            appState.incomingCall = nil
        }
        appState.startPolling()  // ← resume polling
        VoIPManager.shared.clearPendingCall()
        dismiss()
    }

    // MARK: - End
    private func endCall() async {
        agoraManager.leaveChannel()
        VoIPManager.shared.reportCallEnded()  // ← tambah ini

        await MainActor.run {
            appState.inActiveCall = false
            appState.incomingCall = nil
        }

        guard let token = appState.token,
              let url = URL(string: "\(AppConfig.baseURL)/calls/\(callId)/end") else {
            dismiss()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)

        appState.startPolling()
        VoIPManager.shared.clearPendingCall()
        dismiss()
    }

    // MARK: - Check Call Status
    private func checkCallStatus() async {
        guard let token = appState.token,
              let url = URL(string: "\(AppConfig.baseURL)/calls/\(callId)/status")
        else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String
        else { return }

        print("📊 Call status: \(status)")

        if status == "ended" || status == "missed" {
            await MainActor.run {
                agoraManager.leaveChannel()
                appState.inActiveCall = false
                appState.incomingCall = nil
            }
            dismiss()
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
