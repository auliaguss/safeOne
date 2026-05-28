//
//  ReminderDetailView.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import SwiftUI

struct ReminderDetailView: View {
    @Environment(\.dismiss) var dismiss
    let reminder: Reminder

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Photo / Emoji
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 90, height: 90)
                        Text(reminder.imageName ?? "💊")
                            .font(.system(size: 40))
                    }
                    Text("Add photo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                // Title
                HStack {
                    Text(reminder.title)
                        .font(.body)
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                    Spacer()
                }

                Divider().padding(.leading)

                // Notes
                HStack {
                    Text(reminder.notes.isEmpty ? "No notes" : reminder.notes)
                        .foregroundColor(reminder.notes.isEmpty ? .secondary : .primary)
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                    Spacer()
                }

                Divider().padding(.top, 8)

                SectionHeader(title: "Date & Time")

                FormRowDisplay(
                    label: "Date",
                    value: reminder.date.formatted(.dateTime.day().month(.wide).year())
                )
                Divider().padding(.leading)
                FormRowDisplay(
                    label: "Time",
                    value: reminder.date.formatted(.dateTime.hour().minute())
                )

                Divider().padding(.top, 8)

                SectionHeader(title: "Reminder")

                FormRowDisplay(label: "Repeat", value: reminder.repeatOption.rawValue)
                Divider().padding(.leading)
                FormRowDisplay(label: "Early Reminder", value: reminder.earlyReminder.rawValue)
                Divider().padding(.leading)
                FormRowDisplay(label: "Category", value: reminder.category.rawValue)

                Spacer(minLength: 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Reminder Details")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReminderDetailView(reminder: Reminder(
            title: "Vitamin D",
            notes: "1 Tablet",
            date: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
            repeatOption: .everyday,
            earlyReminder: .inTime,
            category: .medication,
            elderID: UUID(),
            imageName: "💊"
        ))
    }
}
