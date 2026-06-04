//
//  DashboardView.swift
//  ElderCareApp
//

import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDate = Date()
    @State private var isShowingCalendar = false

    private var isShowingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Check-In")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { isShowingCalendar.toggle() }) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(isShowingCalendar ? .blue : .primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if isShowingCalendar {
                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
                    .onChange(of: selectedDate) {
                        isShowingCalendar = false
                        Task {
                            await appState.loadDashboardReminders(for: selectedDate)
                        }
                    }
                }

                ElderSelectorView()
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                
                Divider()

                let reminders = appState.remindersForCurrentUser(on: selectedDate)

                if reminders.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text(isShowingToday ? "No reminders today!" : "No reminders on this date.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(reminders) { reminder in
                                DashboardReminderRow(reminder: reminder)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await appState.loadDashboardReminders(for: selectedDate)
            }
            .onChange(of: appState.selectedElderIndex) {
                Task {
                    await appState.loadDashboardReminders(for: selectedDate)
                }
            }
        }
    }
}

struct DashboardReminderRow: View {
    let reminder: Reminder
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH.mm"
        return formatter.string(from: reminder.date)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ReminderImageView(imageName: reminder.imageName)

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
