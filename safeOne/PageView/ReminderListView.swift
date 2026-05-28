//
//  ReminderListView.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import SwiftUI

struct ReminderListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddReminder = false
    @State private var showPastReminders = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Text("Reminder")
                        .font(.headline)
                    Spacer()
                    Button(action: { showAddReminder = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 36, height: 36)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                // Elder Selector
                ElderSelectorView()
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                Divider()

                ScrollView {
                    VStack(spacing: 0) {
                        let active = appState.reminders.filter { !$0.isPast }

                        ForEach(active) { reminder in
                            NavigationLink(destination: ReminderDetailView(reminder: reminder)) {
                                ReminderListRow(reminder: reminder)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider()
                                .padding(.leading, 72)
                        }

                        // Past Reminders toggle
                        Button(action: { showPastReminders.toggle() }) {
                            HStack(spacing: 4) {
                                Text("See Past Reminders")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                Image(systemName: showPastReminders ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 14)
                        }

                        if showPastReminders {
                            let past = appState.reminders.filter { $0.isPast }
                            ForEach(past) { reminder in
                                ReminderListRow(reminder: reminder, isPast: true)
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddReminder) {
                AddReminderView()
            }
        }
    }
}

// MARK: - Reminder List Row

struct ReminderListRow: View {
    let reminder: Reminder
    var isPast: Bool = false

    var subtitleString: String {
        let timeOnly = DateFormatter()
        timeOnly.dateFormat = "HH.mm"
        let full = DateFormatter()
        full.dateFormat = "d MMM, HH.mm"

        switch reminder.repeatOption {
        case .everyday:
            return "Everyday, \(timeOnly.string(from: reminder.date))"
        default:
            return full.string(from: reminder.date)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPast ? Color(.systemGray5) : Color(.systemGray6))
                    .frame(width: 48, height: 48)
                Text(reminder.imageName ?? "💊")
                    .font(.title3)
                    .opacity(isPast ? 0.5 : 1.0)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isPast ? .secondary : .primary)
                Text(subtitleString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ReminderListView()
        .environmentObject(AppState())
}
