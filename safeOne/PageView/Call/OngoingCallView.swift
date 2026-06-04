// OngoingCallView.swift
import SwiftUI

struct OngoingCallView: View {
    var isElder: Bool = false
    var callId: String
    var callDuration: Int = 0

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showSOS = false

    var body: some View {
        VStack(spacing: 0) {
            // Topbar
            ZStack {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(.leading, 16)
                        .onTapGesture { dismiss() }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Emergency Call")
                            .font(.system(size: 17, weight: .semibold))
                        Text(formatTime(callDuration))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(.trailing, 16)
                        .onTapGesture { dismiss() }
                }
            }
            .frame(height: 44)
            .padding(.top, 4)
            .padding(.bottom, 8)

            // Video area
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.933, green: 1.0, blue: 0.988),
                             Color(red: 0.741, green: 0.925, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: isElder ? "person.fill" : "person.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue.opacity(0.4))
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Bottom buttons
            HStack {
                Spacer()

                // End call
                Button {
                    Task {
                        try? await CallService.shared.endCall(
                            callId: callId,
                            token: appState.authToken
                        )
                        // TODO: leave Agora channel
                        dismiss()
                    }
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.red)
                        .clipShape(Circle())
                }

                if !isElder {
                    Spacer()
                    // SOS button
                    Button { showSOS = true } label: {
                        Text("SOS")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                    .sheet(isPresented: $showSOS) {
                        SOSContactsView()
                    }
                }

                Spacer()
            }
            .padding(.vertical, 20)
            .background(Color(UIColor.systemGray6))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
