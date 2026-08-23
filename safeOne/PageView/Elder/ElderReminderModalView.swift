//
//  ElderReminderModalView.swift
//  safeOne
//

import SwiftUI
import AVFoundation
import Combine

struct ElderReminderModalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let reminder: APIReminder
    var onAction: (() -> Void)? = nil

    @StateObject private var speech = SpeechHelper()
    @State private var isDone: Bool = false
    @State private var isActing = false
    @State private var showSuccess = false
    @State private var successScale: CGFloat = 0.5
    @State private var actionError: String? = nil

    private var displayTimes: [String] {
        let t = (reminder.times ?? []).filter { !$0.isEmpty }
        if !t.isEmpty { return t }
        guard let d = APIReminder.parseDate(reminder.date) else { return [] }
        let f = DateFormatter(); f.timeZone = TimeZone(abbreviation: "UTC"); f.dateFormat = "HH:mm"
        return [f.string(from: d)]
    }

    private var activeTimeIndex: Int { nearestTimeIndex(in: displayTimes) }

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
            if showSuccess {
                successView
            } else {
                normalContent
            }
        }
        .onAppear {
            isDone = reminder.isCompleted
            speech.speak(reminder.title, languageIdentifier: appState.language.localeIdentifier)
        }
        .onDisappear { speech.stop() }
    }

    // MARK: - Success state

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .scaleEffect(successScale)
            Text("Done! Great job ✓")
                .font(.system(size: 26, weight: .bold, design: .rounded))
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

    // MARK: - Normal content

    private var normalContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Image / Emoji circle
                ReminderImageView(
                    imageName: reminder.imageName,
                    size: 160,
                    isCircle: true,
                    background: Color(hex: "F2F2F7")
                )
                .padding(.bottom, 20)

                // Info
                VStack(spacing: 8) {
                    Text(reminder.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    if let notes = reminder.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }

                    if let cat = reminder.category, cat.lowercased() != "none", !cat.isEmpty {
                        Text(reminder.localizedCategory)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Times
                if !displayTimes.isEmpty {
                    let active = activeTimeIndex
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(Color(hex: "007AFF"))
                                .font(.system(size: 18))
                            ForEach(Array(displayTimes.enumerated()), id: \.offset) { i, utcTime in
                                let isActive = i == active
                                Text(utcToLocal(utcTime))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(isActive ? .white : Color(hex: "007AFF"))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isActive ? Color(hex: "007AFF") : Color(hex: "007AFF").opacity(0.12))
                                    .cornerRadius(18)
                            }
                        }
                        .frame(minWidth: UIScreen.main.bounds.width, alignment: .center)
                    }
                    .padding(.bottom, 24)
                }

                // Action buttons
                VStack(spacing: 12) {
                    if let err = actionError {
                        Text(err)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        speech.speak(reminder.title, languageIdentifier: appState.language.localeIdentifier)
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

                    Button(action: { Task { await snooze() } }) {
                        Text("Snooze 5 minutes")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(Color(hex: "007AFF"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "007AFF"), lineWidth: 1))
                    }
                    .disabled(isActing || isDone || reminder.isCompleted)

                    Button(action: { Task { await markDone() } }) {
                        Text(appState.text(
                            isDone || reminder.isCompleted ? "Sudah Selesai ✓" : "Tandai Selesai",
                            isDone || reminder.isCompleted ? "Already Done ✓" : "Mark as Done"
                        ))
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isDone || reminder.isCompleted ? Color.green : Color(hex: "007AFF"))
                            .cornerRadius(14)
                    }
                    .disabled(isActing || isDone || reminder.isCompleted)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                            .font(.body)
                            .padding(8)
                            .background(Color(hex: "F2F2F7"))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func markDone() async {
        guard !isActing else { return }
        isActing = true
        actionError = nil
        speech.stop()
        await MainActor.run {
            successScale = 0.5
            showSuccess = true
        }

        let result = try? await ReminderRepository.markDone(id: reminder.id, token: appState.authToken)

        if result != nil {
            await MainActor.run { isDone = true }
            onAction?()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { dismiss() }
        } else {
            await MainActor.run {
                showSuccess = false
                isActing = false
                actionError = "Couldn't mark as done. Please try again."
            }
        }
    }

    private func snooze() async {
        guard !isActing else { return }
        isActing = true
        speech.stop()
        try? await ReminderRepository.snoozeReminder(id: reminder.id, token: appState.authToken)
        await MainActor.run {
            isActing = false
            dismiss()
        }
    }
}
