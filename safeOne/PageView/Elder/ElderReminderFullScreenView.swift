//
//  ElderReminderFullScreenView.swift
//  safeOne
//

import Combine
import SwiftUI
import AVFoundation

// Keeps the AVSpeechSynthesizer alive for the duration of the view.
// objectWillChange is provided explicitly to avoid synthesis issues.
final class SpeechHelper: ObservableObject {
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
    @State private var fetchedImageName: String? = nil
    @State private var fetchedTimes: [String] = []

    private var displayTimes: [String] {
        if !fetchedTimes.isEmpty { return fetchedTimes }
        guard let d = APIReminder.parseDate(reminder.time) else { return [] }
        let f = DateFormatter(); f.timeZone = TimeZone(abbreviation: "UTC"); f.dateFormat = "HH:mm"
        let t = f.string(from: d)
        return t.isEmpty ? [] : [t]
    }

    private var activeTimeIndex: Int {
        let times = displayTimes
        guard !times.isEmpty else { return 0 }
        if let triggerDate = APIReminder.parseDate(reminder.time) {
            let f = DateFormatter(); f.timeZone = TimeZone(abbreviation: "UTC"); f.dateFormat = "HH:mm"
            if let idx = times.firstIndex(of: f.string(from: triggerDate)) { return idx }
        }
        return nearestTimeIndex(in: times)
    }

    private func nearestTimeIndex(in times: [String]) -> Int {
        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(abbreviation: "UTC")!
        let comps = cal.dateComponents([.year, .month, .day], from: now)
        var futureIdx = 0, futureMin = TimeInterval.infinity
        var pastIdx = 0, pastMax = -TimeInterval.infinity
        var hasFuture = false, hasPast = false
        for (i, t) in times.enumerated() {
            let p = t.split(separator: ":").compactMap { Int($0) }
            guard p.count >= 2 else { continue }
            var c = comps; c.hour = p[0]; c.minute = p[1]; c.second = 0
            guard let d = cal.date(from: c) else { continue }
            let diff = d.timeIntervalSince(now)
            if diff >= 0 { if diff < futureMin { futureMin = diff; futureIdx = i; hasFuture = true } }
            else { if diff > pastMax { pastMax = diff; pastIdx = i; hasPast = true } }
        }
        return hasFuture ? futureIdx : (hasPast ? pastIdx : 0)
    }

    private func utcToLocal(_ s: String) -> String {
        let f = DateFormatter(); f.timeZone = TimeZone(abbreviation: "UTC"); f.dateFormat = "HH:mm"
        guard let d = f.date(from: s) else { return s }
        let lf = DateFormatter(); lf.dateFormat = "HH:mm"
        return lf.string(from: d)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if showSuccess { successView } else { mainContent }
        }
        .onAppear {
            speech.speak(reminder.title)
            Task {
                if let fetched = try? await ReminderRepository.fetchReminder(id: reminder.id, token: appState.authToken) {
                    await MainActor.run {
                        fetchedImageName = fetched.imageName
                        fetchedTimes = fetched.times ?? []
                    }
                }
            }
        }
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

            // Image / Emoji
            ReminderImageView(
                imageName: fetchedImageName ?? reminder.imageName,
                size: 260,
                isCircle: true,
                background: Color(hex: "F2F2F7")
            )
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

            // Times
            if !displayTimes.isEmpty {
                let active = activeTimeIndex
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(Color(hex: "007AFF"))
                            .font(.system(size: 20))
                        ForEach(Array(displayTimes.enumerated()), id: \.offset) { i, utcTime in
                            let isActive = i == active
                            Text(utcToLocal(utcTime))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(isActive ? .white : Color(hex: "007AFF"))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(isActive ? Color(hex: "007AFF") : Color(hex: "007AFF").opacity(0.12))
                                .cornerRadius(22)
                        }
                    }
                    .frame(minWidth: UIScreen.main.bounds.width, alignment: .center)
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
