//
//  ElderDashboard.swift
//  safeOne
//

import SwiftUI
import AVFoundation

struct ElderDashboard: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ReminderViewModel()

    @State private var showCallingScreen = false
    @State private var selectedReminder: APIReminder? = nil

    private func byDate(_ a: APIReminder, _ b: APIReminder) -> Bool {
        (APIReminder.parseDate(a.date) ?? .distantFuture) < (APIReminder.parseDate(b.date) ?? .distantFuture)
    }

    private var activeToday: [APIReminder] {
        vm.reminders.filter { !$0.isCompleted }.sorted(by: byDate)
    }
    private var doneToday: [APIReminder] {
        vm.reminders.filter { $0.isCompleted }.sorted(by: byDate)
    }

    private var formattedToday: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, d MMM yyyy"
        return fmt.string(from: Date())
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Reminder")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        Text(formattedToday)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    } else {
                        // Step 5.3 — "Caught up" state when no active reminders
                        if activeToday.isEmpty {
                            caughtUpView
                        }

                        if !activeToday.isEmpty {
                            reminderSection("Today's Reminder", items: activeToday, tappable: true, completed: false)
                        }
                        if !doneToday.isEmpty {
                            reminderSection("Done Today", items: doneToday, tappable: false, completed: true)
                        }
                    }

                    Spacer(minLength: 96)
                }
            }

            // Step 5.4 — Accessible SOS button with text label
            Button(action: {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                showCallingScreen = true
            }) {
                VStack(spacing: 2) {
                    Image(systemName: "phone.fill").font(.title2)
                    Text("SOS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(width: 68, height: 68)
                .background(Color(hex: "FF5E5B")).clipShape(Circle())
                .shadow(color: Color(hex: "FF5E5B").opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .accessibilityLabel("Emergency SOS call")
            .padding(.trailing, 24)
            .padding(.bottom, 20)
        }
        .sheet(item: $selectedReminder) { item in
            ElderReminderModalView(
                reminder: item,
                onAction: { Task { await vm.fetchReminders(token: appState.authToken) } }
            )
            .environmentObject(appState)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showCallingScreen) {
            ElderCallingView()
        }
        .task {
            // Initial load
            await vm.loadForElder(token: appState.authToken)

            // Handle deep-link from cold-start notification tap
            if let id = appState.pendingReminderDeepLink,
               let reminder = vm.reminders.first(where: { $0.id == id }) {
                selectedReminder = reminder
                appState.pendingReminderDeepLink = nil
            }

            // Polling loop — keeps elder dashboard in sync with child edits.
            // SwiftUI cancels this task automatically when the view disappears.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 s
                await vm.fetchReminders(token: appState.authToken)
            }
        }
        // Step 4.2 — Handle deep-link while app is already running
        .onChange(of: appState.pendingReminderDeepLink) { _, newId in
            guard let id = newId else { return }
            if let reminder = vm.reminders.first(where: { $0.id == id }) {
                selectedReminder = reminder
                appState.pendingReminderDeepLink = nil
            }
        }
        .onAppear {
            AVAudioApplication.requestRecordPermission { _ in }
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }
    }

    // MARK: - "All caught up" empty state (Step 5.3)

    private var caughtUpView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.yellow, Color.orange)
            Text("You're all caught up!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.black)
            Text(doneToday.isEmpty
                 ? "No reminders today, enjoy your day."
                 : "All reminders for today are done.")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - Section builder

    @ViewBuilder private func reminderSection(
        _ title: String,
        items: [APIReminder],
        tappable: Bool,
        completed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(completed ? .secondary : .black)
                .padding(.horizontal, 24)

            ForEach(items) { item in
                ElderReminderCard(
                    reminder: item,
                    isCompleted: completed,
                    onTap: tappable ? { selectedReminder = item } : nil
                )
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Elder Reminder Card

struct ElderReminderCard: View {
    let reminder: APIReminder
    var isCompleted: Bool = false
    var onTap: (() -> Void)? = nil

    private var incomingText: String? {
        guard !isCompleted else { return nil }
        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(abbreviation: "UTC")!
        let todayUTC = cal.dateComponents([.year, .month, .day], from: now)
        let t = (reminder.times ?? []).filter { !$0.isEmpty }
        if !t.isEmpty {
            var nextDate: Date? = nil
            for timeStr in t {
                let p = timeStr.split(separator: ":").compactMap { Int($0) }
                guard p.count >= 2 else { continue }
                var c = todayUTC; c.hour = p[0]; c.minute = p[1]; c.second = 0
                guard let d = cal.date(from: c), d >= now else { continue }
                if nextDate == nil || d < nextDate! { nextDate = d }
            }
            guard let next = nextDate else { return nil }
            return formatIncoming(next.timeIntervalSince(now))
        }
        guard let d = APIReminder.parseDate(reminder.date), d >= now else { return nil }
        return formatIncoming(d.timeIntervalSince(now))
    }

    private func formatIncoming(_ interval: TimeInterval) -> String {
        let mins = Int(interval / 60)
        if mins < 60 { return "in \(mins) min\(mins == 1 ? "" : "s")" }
        let hours = mins / 60
        return "in \(hours) hour\(hours == 1 ? "" : "s")"
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                // Step 5.4 — Min 56 px icon area
                ReminderImageView(
                    imageName: reminder.imageName,
                    size: 56,
                    opacity: isCompleted ? 0.5 : 1.0,
                    background: isCompleted ? Color(hex: "F2F2F7") : Color(hex: "E8F3FF"),
                    cornerRadius: 16
                )

                VStack(alignment: .leading, spacing: 5) {
                    // Step 5.4 — 17 pt minimum for body text
                    Text(reminder.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(isCompleted ? .secondary : .black)
                        .strikethrough(isCompleted, color: .secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.caption)
                        Text(reminder.timesText).font(.system(size: 15, design: .rounded))
                        if let cat = reminder.category, cat.lowercased() != "none", !cat.isEmpty {
                            Text("·")
                            Text(cat.capitalized).font(.system(size: 15, design: .rounded))
                        }
                    }
                    .foregroundColor(isCompleted ? .secondary : .gray)

                    if let notes = reminder.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if isCompleted && reminder.repeatOption != "none" {
                        Text("Repeats \(reminder.repeatOption.lowercased())")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color(hex: "007AFF").opacity(0.85))
                    }
                }

                Spacer()

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green).font(.title2)
                } else if let incoming = incomingText {
                    Text(incoming)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "007AFF"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().stroke(Color(hex: "007AFF"), lineWidth: 1))
                }
            }
            .padding(.all, 16)
            // Step 5.4 — Min 80 px overall card height (icon 56 + 2×12 padding)
            .frame(minHeight: 80)
            .background(Color.white)
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
        .opacity(isCompleted ? 0.82 : 1.0)
        .disabled(onTap == nil)
        .accessibilityHint(onTap != nil ? "Tap to see details and mark as done" : "")
    }
}

#Preview {
    ElderDashboard()
        .environmentObject(AppState())
}
