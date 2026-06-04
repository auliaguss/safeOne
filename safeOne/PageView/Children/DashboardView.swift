//
//  DashboardView.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Check-In")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Elder Selector
                ElderSelectorView()
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                Divider()

                // Reminders
                let todayReminders = appState.todayReminders(for: appState.selectedElder)

                if todayReminders.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No reminders today!")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(todayReminders) { reminder in
                                DashboardReminderRow(reminder: reminder)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Dashboard Reminder Row

struct DashboardReminderRow: View {
    let reminder: Reminder

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let nextDate = reminder.nextOccurrence(after: Date()) ?? reminder.date
        return formatter.string(from: nextDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(width: 48, height: 48)
                Text(reminder.imageName ?? "💊")
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(timeString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            StatusBadgeView(reminder: reminder)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Status Badge

struct StatusBadgeView: View {
    let reminder: Reminder

    var body: some View {
        if reminder.isCompleted && reminder.totalCount == 1 {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        } else if reminder.totalCount > 1 {
            ZStack {
                Circle()
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: 36, height: 36)
                Text("\(reminder.completedCount)/\(reminder.totalCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        } else {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 1.5)
                    .frame(width: 32, height: 32)
                Text("\(reminder.completedCount)/\(reminder.totalCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
}
