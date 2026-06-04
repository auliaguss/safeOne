//
//  ElderCallingView.swift
//  safeOne
//

import SwiftUI
import Combine

struct ElderCallingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject private var agoraManager = AgoraManager.shared

    @State private var isConnected = false
    @State private var callDuration = 0
    @State private var errorMessage: String? = nil
    @State private var activeCallData: InitiateCallResponse? = nil
    @State private var hasRemoteUserJoined = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if isConnected {
                if let remoteUid = agoraManager.remoteUid {
                    VideoView(uid: remoteUid, agoraManager: agoraManager)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                    VStack {
                        Spacer()
                        ProgressView().tint(.white)
                        Text("Menunggu caregiver...")
                            .foregroundColor(.white)
                            .padding(.top, 8)
                        Spacer()
                    }
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
                                .background(Color(hex: "FF3B30"))
                                .clipShape(Circle())
                                .shadow(color: Color(hex: "FF3B30").opacity(0.3), radius: 8, x: 0, y: 4)
                        }

                        Button { agoraManager.toggleVideo() } label: {
                            Image(systemName: agoraManager.isLocalVideoMuted ? "video.slash.fill" : "video.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 48)
                }

            } else {
                Color(hex: "F2F2F7").ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button { Task { await cancelCall() } } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .foregroundColor(.black)
                                .padding(.all, 12)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Spacer()

                    Text("Calling for Help")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.bottom, 60)

                    ZStack {
                        Circle()
                            .fill(Color(hex: "007AFF").opacity(0.15))
                            .frame(width: 240, height: 240)
                        Circle()
                            .fill(Color(hex: "007AFF"))
                            .frame(width: 180, height: 180)
                            .shadow(color: Color(hex: "007AFF").opacity(0.3), radius: 15, x: 0, y: 8)
                        Image(systemName: "phone.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Text("If this was a mistake,\nplease tap Cancel.")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 40)

                    Button { Task { await cancelCall() } } label: {
                        Text("Cancel")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(hex: "007AFF"))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            if let appId = activeCallData?.agoraAppId {
                agoraManager.setup(appId: appId)
            }
            Task { await initiateCallAPI() }
        }
        .onDisappear {
            agoraManager.leaveChannel()
        }
        // ✅ POLLING: Cek status call ke backend setiap 3 detik
        .onReceive(timer) { _ in
            if isConnected {
                callDuration += 1

                if callDuration % 3 == 0 {
                    Task { await checkCallStatus() }
                }
            }
        }
        // Tetap pertahankan sebagai backup, tapi polling yang jadi andalan
        .onChange(of: agoraManager.remoteUid) { newUid in
            if newUid != nil {
                hasRemoteUserJoined = true
            } else if newUid == nil && hasRemoteUserJoined {
                print("👤 Remote user offline — menutup call dari onChange")
                Task { await endCall() }
            }
        }
    }

    // MARK: - Check Call Status (Polling)
    // Dipanggil setiap 3 detik untuk tahu apakah children sudah end call
    private func checkCallStatus() async {
        guard let callId = activeCallData?.callId,
              let token = appState.token,
              let url = URL(string: "https://safe-one-backend.vercel.app/api/calls/\(callId)/status")
        else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String
        else { return }

        print("📊 Call status dari backend: \(status)")

        // Jika backend bilang call sudah ended → tutup layar elder
        if status == "ended" || status == "missed" || status == "cancelled" || status == "declined" {  // ← tambah "missed"
                print("✅ Call ended/missed — menutup ElderCallingView")
                await MainActor.run {
                    agoraManager.leaveChannel()
                    dismiss()
                }
            }
    }

    // MARK: - Initiate Call
    private func initiateCallAPI() async {
        guard let token = appState.token else {
            await MainActor.run { errorMessage = "Sesi tidak valid, silakan login ulang." }
            return
        }

        guard let url = URL(string: "https://safe-one-backend.vercel.app/api/calls/initiate") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode == 200 {
                let decoded = try JSONDecoder().decode(InitiateCallResponse.self, from: data)
                await MainActor.run {
                    self.activeCallData = decoded
                    agoraManager.setup(appId: decoded.agoraAppId)
                    agoraManager.joinChannel(token: decoded.agoraToken, channelName: decoded.channelName)
                    withAnimation { self.isConnected = true }
                }
            } else {
                let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMsg = errorResponse?["error"] as? String ?? "Terjadi kesalahan"
                await MainActor.run { self.errorMessage = errorMsg }
            }
        } catch {
            await MainActor.run { self.errorMessage = "Gagal terhubung ke server." }
        }
    }

    // MARK: - End Call
    private func endCall() async {
        agoraManager.leaveChannel()
        if let callId = activeCallData?.callId, let token = appState.token {
            guard let url = URL(string: "https://safe-one-backend.vercel.app/api/calls/\(callId)/end") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
        dismiss()
    }

    // MARK: - Cancel
    private func cancelCall() async {
        agoraManager.leaveChannel()
        if let callId = activeCallData?.callId, let token = appState.token {
            guard let url = URL(string: "https://safe-one-backend.vercel.app/api/calls/\(callId)/end") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
        dismiss()
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
