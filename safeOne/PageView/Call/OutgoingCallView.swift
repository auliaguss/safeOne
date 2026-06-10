// OutgoingCallView.swift
import SwiftUI
import Combine

struct OutgoingCallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var callData: InitiateCallResponse? = nil
    @State private var isConnected = false
    @State private var errorMessage: String? = nil
    @State private var callDuration = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0, green: 218/255, blue: 195/255).opacity(0.15), Color.clear],
                center: UnitPoint(x: 0.2, y: 0.1),
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0, green: 145/255, blue: 1.0).opacity(0.20), Color.clear],
                center: UnitPoint(x: 0.8, y: 0.8),
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            if !isConnected {
                // Outgoing / waiting state
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 16, weight: .medium))
                            .padding(.trailing, 24)
                            .padding(.top, 8)
                    }

                    Spacer()

                    Text("Calling for Help")
                        .font(.system(size: 30, weight: .bold))
                        .padding(.bottom, 48)

                    ZStack {
                        Circle().fill(Color.blue.opacity(0.15)).frame(width: 200, height: 200)
                        Circle().fill(Color.blue).frame(width: 160, height: 160)
                        Image(systemName: "phone.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    Spacer()

                    Text("If this was a mistake,\nplease tap Cancel.")
                        .font(.system(size: 17))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 32)

                    Button {
                        Task {
                            if let callId = callData?.callId {
                                try? await CallService.shared.endCall(
                                    callId: callId,
                                    token: appState.authToken
                                )
                            }
                            dismiss()
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.blue)
                            .cornerRadius(14)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 48)
                }
            } else {
                // Connected state — reuse OngoingCallView
                OngoingCallView(
                    isElder: true,
                    callId: callData?.callId ?? "",
                    callDuration: callDuration
                )
            }
        }
        .onAppear {
            Task { await startCall() }
        }
        .onReceive(timer) { _ in
            if isConnected { callDuration += 1 }
        }
    }

    private func startCall() async {
        do {
            let data = try await CallService.shared.initiateCall(token: appState.authToken)
            await MainActor.run {
                self.callData = data
                // TODO: join Agora channel dengan data.agoraToken + data.channelName
                withAnimation { self.isConnected = true }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
