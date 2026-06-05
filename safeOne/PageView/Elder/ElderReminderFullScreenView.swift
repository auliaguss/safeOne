//
//  ElderReminderFullScreenView.swift
//  safeOne
//

import Combine
import SwiftUI
import AVFoundation

// Keeps the AVSpeechSynthesizer alive for the duration of the view.
// objectWillChange is provided explicitly to avoid synthesis issues.
private final class SpeechHelper: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synth.stopSpeaking(at: .immediate)

        #if os(iOS)
        // Let TTS play even in silent mode
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let utt = AVSpeechUtterance(string: text)
        utt.rate   = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utt.volume = 1.0
        // Use device locale; falls back to system default if unavailable
        let langCode = Locale.current.identifier
        if let voice = AVSpeechSynthesisVoice(language: langCode) {
            utt.voice = voice
        }
        synth.speak(utt)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}

struct ElderReminderFullScreenView: View {
    @EnvironmentObject var appState: AppState
    let reminder: ReminderNotificationData

    @StateObject private var speech = SpeechHelper()
    @State private var isActing     = false
    @State private var showSuccess  = false
    @State private var successScale: CGFloat = 0.5

    private var formattedTime: String {
        guard let d = APIReminder.parseDate(reminder.time) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: d)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if showSuccess { successView } else { mainContent }
        }
        .onAppear  { speech.speak(reminder.title) }
        .onDisappear { speech.stop() }
    }

    // MARK: - Success state

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)
                .scaleEffect(successScale)
            Text("Done! Great job ✓")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.black)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                successScale = 1.0
            }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Close / dismiss
            HStack {
                Spacer()
                Button { dismissAlert() } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.black)
                        .font(.title3)
                        .padding(12)
                        .background(Color(hex: "F2F2F7"))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Dismiss reminder")
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Emoji
            ZStack {
                Circle()
                    .fill(Color(hex: "F2F2F7"))
                    .frame(width: 260, height: 260)
                Text(reminder.imageName ?? "💊")
                    .font(.system(size: 110))
            }
            .padding(.bottom, 30)

            // Info
            VStack(spacing: 10) {
                Text(reminder.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                if let cat = reminder.category, !cat.isEmpty, cat.lowercased() != "none" {
                    Text(cat.capitalized)
                        .font(.system(size: 17, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            // Time
            if !formattedTime.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(Color(hex: "007AFF"))
                    Text(formattedTime)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "007AFF"))
                }
                .padding(.bottom, 32)
            }

            // Action buttons
            VStack(spacing: 14) {
                // Re-read button
                Button {
                    speech.speak(reminder.title)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("Read Again")
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(Color(hex: "007AFF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "007AFF"), lineWidth: 1))
                }

                Button { Task { await snooze() } } label: {
                    Text("Snooze 5 minutes")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Color(hex: "007AFF"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "007AFF"), lineWidth: 1))
                }
                .disabled(isActing)

                Button { Task { await markDone() } } label: {
                    Text("Mark as Done")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(hex: "007AFF"))
                        .cornerRadius(14)
                }
                .disabled(isActing)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
        }
    }

    // MARK: - Actions

    private func dismissAlert() {
        speech.stop()
        appState.activeReminderAlert = nil
    }

    private func markDone() async {
        guard !isActing else { return }
        isActing = true
        speech.stop()
        // Show success immediately (optimistic)
        await MainActor.run {
            successScale = 0.5
            showSuccess = true
        }
        _ = try? await ReminderRepository.markDone(id: reminder.id, token: appState.authToken)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await MainActor.run { appState.activeReminderAlert = nil }
    }

    private func snooze() async {
        guard !isActing else { return }
        isActing = true
        speech.stop()
        try? await ReminderRepository.snoozeReminder(id: reminder.id, token: appState.authToken)
        await MainActor.run { appState.activeReminderAlert = nil }
    }
}
