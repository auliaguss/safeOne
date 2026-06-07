import SwiftUI
import UIKit

struct ElderDashboard: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedReminder: Reminder?
    @State private var showMissingContactAlert = false

    private var todaysReminders: [Reminder] {
        appState.remindersForCurrentUser(on: Date())
    }

    private var todaysEvents: [Reminder] {
        todaysReminders.filter { $0.category == .appointment }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F2F2F7")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Reminder")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Events")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            if todaysEvents.isEmpty {
                                Text("No events today.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            } else {
                                ForEach(todaysEvents) { reminder in
                                    ElderEventRow(reminder: reminder) {
                                        selectedReminder = reminder
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Reminders")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            VStack(spacing: 12) {
                                if todaysReminders.isEmpty {
                                    Text("No reminders today.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white)
                                        .cornerRadius(14)
                                } else {
                                    ForEach(todaysReminders) { reminder in
                                        ElderReminderRow(reminder: reminder) {
                                            selectedReminder = reminder
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()

                    Button(action: {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        if appState.faceTimeContact() != nil {
                            appState.openFaceTime()
                        } else {
                            showMissingContactAlert = true
                        }
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color(hex: "FF5E5B"))
                            .clipShape(Circle())
                            .shadow(color: Color(hex: "FF5E5B").opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    .accessibilityLabel("FaceTime caregiver")
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color(hex: "F2F2F7").opacity(0.96))
            }
            .sheet(item: $selectedReminder) { item in
                ElderReminderModalView(reminder: item)
            }
            .task {
                await appState.loadDashboardReminders(for: Date())
            }
            .alert("No FaceTime Contact", isPresented: $showMissingContactAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Add a primary caregiver contact in Emergency Services before using the one-tap call button.")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ElderReminderRow: View {
    let reminder: Reminder
    let action: () -> Void

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: reminder.date)
    }

    private var statusText: String {
        if reminder.isCompleted { return "done" }
        let minutes = Int(reminder.date.timeIntervalSinceNow / 60)
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "in \(minutes) min" }
        return "in \(minutes / 60) hours"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    ReminderImageView(imageName: reminder.imageName)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    Text(reminder.notes.isEmpty ? reminder.category.displayName : reminder.notes)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(timeText)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "007AFF"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().stroke(Color(hex: "007AFF"), lineWidth: 1))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(18)
        }
    }
}

private struct ElderEventRow: View {
    let reminder: Reminder
    let action: () -> Void

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH.mm"
        return formatter.string(from: reminder.date)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ReminderImageView(imageName: reminder.imageName, fallback: "🩺")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(timeText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Details", action: action)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: "3A86F5"))
                .cornerRadius(10)
                .fixedSize()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }
}

#Preview {
    ElderDashboard()
}
