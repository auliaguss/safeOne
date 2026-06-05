//
//  ReminderDetailView.swift
//  safeOne
//

import SwiftUI

struct ReminderDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let reminder: APIReminder
    var onChanged: (() -> Void)? = nil

    @State private var showEdit = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var didEdit = false

    // Parse the ISO-8601 string (with or without milliseconds) into a Date for display
    private var reminderDate: Date? { APIReminder.parseDate(reminder.date) }

    private var formattedDate: String {
        guard let d = reminderDate else { return "-" }
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMMM yyyy"
        return fmt.string(from: d)
    }

    private var formattedTime: String {
        guard let d = reminderDate else { return "-" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: d)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Emoji
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 90, height: 90)
                        Text(reminder.imageName ?? "💊")
                            .font(.system(size: 40))
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                HStack {
                    Text(reminder.title)
                        .font(.body)
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                    Spacer()
                }

                Divider().padding(.leading)

                HStack {
                    let notes = reminder.notes ?? ""
                    Text(notes.isEmpty ? "No notes" : notes)
                        .foregroundColor(notes.isEmpty ? .secondary : .primary)
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                    Spacer()
                }

                Divider().padding(.top, 8)

                SectionHeader(title: "Date & Time")
                FormRowDisplay(label: "Date", value: formattedDate)
                Divider().padding(.leading)
                FormRowDisplay(label: "Time", value: formattedTime)

                Divider().padding(.top, 8)

                SectionHeader(title: "Reminder")
                FormRowDisplay(label: "Repeat", value: reminder.repeatDisplayName)
                Divider().padding(.leading)
                FormRowDisplay(label: "Early Reminder", value: (reminder.earlyReminder ?? "none").replacingOccurrences(of: "_", with: " ").capitalized)
                Divider().padding(.leading)
                FormRowDisplay(label: "Category", value: (reminder.category ?? "none").capitalized)

                Divider().padding(.top, 8)
                SectionHeader(title: "Progress")
                VStack(spacing: 6) {
                    ProgressView(
                        value: Double(reminder.completedCount),
                        total: Double(max(reminder.totalCount, 1))
                    )
                    .tint(.blue)
                    HStack {
                        Text("\(reminder.completedCount) of \(reminder.totalCount) completed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)

                Divider().padding(.top, 8)
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView().tint(.red)
                        } else {
                            Text("Delete Reminder").fontWeight(.medium)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
                .foregroundColor(.red)
                .disabled(isDeleting)

                Spacer(minLength: 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Reminder Details").font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil").font(.body)
                }
            }
        }
        // When the edit sheet closes, if a save happened: refresh list and pop back
        .sheet(isPresented: $showEdit, onDismiss: {
            if didEdit {
                onChanged?()
                dismiss()
            }
            didEdit = false
        }) {
            AddReminderView(
                initialElderId: reminder.elderId,
                editingReminder: reminder,
                onSaved: { didEdit = true }
            )
            .environmentObject(appState)
        }
        .alert("Delete Reminder", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await deleteReminder() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(reminder.title)\"?")
        }
    }

    private func deleteReminder() async {
        guard let token = appState.token else { return }
        isDeleting = true
        do {
            try await ReminderRepository.deleteReminder(id: reminder.id, token: token)
            await MainActor.run {
                isDeleting = false
                onChanged?()
                dismiss()
            }
        } catch {
            await MainActor.run { isDeleting = false }
        }
    }
}
