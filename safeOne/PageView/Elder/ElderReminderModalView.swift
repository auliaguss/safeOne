//
//  ElderReminderModalView.swift
//  safeOne
//

import SwiftUI

struct ElderReminderModalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let reminder: APIReminder
    var onAction: (() -> Void)? = nil

    @State private var isDone: Bool = false
    @State private var isActing = false
    @State private var showSuccess = false
    @State private var successScale: CGFloat = 0.5
    @State private var actionError: String? = nil

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if showSuccess {
                successView
            } else {
                normalContent
            }
        }
        .onAppear { isDone = reminder.isCompleted }
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
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.black)
                        .font(.title3)
                        .padding(12)
                        .background(Color(hex: "F2F2F7"))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Emoji circle
            ZStack {
                Circle()
                    .fill(Color(hex: "F2F2F7"))
                    .frame(width: 160, height: 160)
                Text(reminder.imageName ?? "💊")
                    .font(.system(size: 72))
            }
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
                    Text(cat.capitalized)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Time
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundColor(Color(hex: "007AFF"))
                Text(reminder.formattedTime)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "007AFF"))
            }
            .padding(.bottom, 24)

            // Action buttons
            VStack(spacing: 12) {
                if let err = actionError {
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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
                    Text(isDone || reminder.isCompleted ? "Already Done ✓" : "Mark as Done")
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
    }

    // MARK: - Actions

    private func markDone() async {
        guard !isActing else { return }
        isActing = true
        actionError = nil
        // Step 5.2 — Optimistic: show success immediately, rollback on failure
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
        try? await ReminderRepository.snoozeReminder(id: reminder.id, token: appState.authToken)
        await MainActor.run {
            isActing = false
            dismiss()
        }
    }
}
