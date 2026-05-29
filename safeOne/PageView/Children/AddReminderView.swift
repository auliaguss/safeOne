//
//  AddReminderView.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import SwiftUI

struct AddReminderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedTime: Date = Date()
    @State private var repeatOption: RepeatOption = .none
    @State private var earlyReminder: EarlyReminderOption = .none
    @State private var category: ReminderCategory = .none
    @State private var selectedEmoji: String = "💊"
    @State private var showDatePicker = false
    @State private var showTimePicker = false

    let emojiOptions: [String] = ["💊", "🩺", "🏃", "🍎", "💉", "🩹", "🧘", "🚶"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // Emoji / Photo Picker
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 90, height: 90)
                            Text(selectedEmoji)
                                .font(.system(size: 40))
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(emojiOptions.indices, id: \.self) { i in
                                    let emoji = emojiOptions[i]
                                    Button(action: { selectedEmoji = emoji }) {
                                        Text(emoji)
                                            .font(.title2)
                                            .padding(8)
                                            .background(
                                                Circle()
                                                    .fill(selectedEmoji == emoji
                                                          ? Color.blue.opacity(0.15)
                                                          : Color.clear)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        Text("Add photo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider()

                    // Title & Notes
                    TextField("Title", text: $title)
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                    Divider().padding(.leading)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                        .padding(.horizontal)
                        .padding(.vertical, 14)

                    Divider().padding(.top, 8)

                    // Date & Time
                    SectionHeader(title: "Date & Time")

                    Button(action: { showDatePicker.toggle() }) {
                        FormPickerRowDisplay(
                            label: "Date",
                            value: selectedDate.formatted(.dateTime.month(.abbreviated).day().year())
                        )
                    }

                    if showDatePicker {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                    }

                    Divider().padding(.leading)

                    Button(action: { showTimePicker.toggle() }) {
                        FormPickerRowDisplay(
                            label: "Time",
                            value: selectedTime.formatted(.dateTime.hour().minute())
                        )
                    }

                    if showTimePicker {
                        DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .padding(.horizontal)
                    }

                    Divider().padding(.top, 8)

                    // Reminder Options
                    SectionHeader(title: "Reminder")

                    Menu {
                        ForEach(RepeatOption.allCases, id: \.self) { option in
                            Button(option.rawValue) { repeatOption = option }
                        }
                    } label: {
                        FormPickerRowDisplay(label: "Repeat", value: repeatOption.rawValue)
                    }

                    Divider().padding(.leading)

                    Menu {
                        ForEach(EarlyReminderOption.allCases, id: \.self) { option in
                            Button(option.rawValue) { earlyReminder = option }
                        }
                    } label: {
                        FormPickerRowDisplay(label: "Early Reminder", value: earlyReminder.rawValue)
                    }

                    Divider().padding(.leading)

                    Menu {
                        ForEach(ReminderCategory.allCases, id: \.self) { option in
                            Button(option.rawValue) { category = option }
                        }
                    } label: {
                        FormPickerRowDisplay(label: "Category", value: category.rawValue)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Add Reminder")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveReminder) {
                        ZStack {
                            Circle()
                                .fill(title.isEmpty ? Color(.systemGray4) : Color.blue)
                                .frame(width: 32, height: 32)
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    func saveReminder() {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComps = cal.dateComponents([.hour, .minute], from: selectedTime)
        comps.hour = timeComps.hour
        comps.minute = timeComps.minute
        let finalDate = cal.date(from: comps) ?? selectedDate

        let newReminder = Reminder(
            title: title,
            notes: notes,
            date: finalDate,
            repeatOption: repeatOption,
            earlyReminder: earlyReminder,
            category: category,
            elderID: appState.selectedElder?.id ?? UUID(),
            imageName: selectedEmoji
        )
        appState.addReminder(newReminder)
        dismiss()
    }
}

// MARK: - Shared Row Component

struct FormPickerRowDisplay: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}
