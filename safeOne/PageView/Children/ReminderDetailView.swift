//
//  ReminderDetailView.swift
//  safeOne
//

import SwiftUI

struct ReminderDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let reminder: APIReminder
    var onMarkDone: (() -> Void)? = nil

    @State private var isMarking = false
    @State private var isDone: Bool = false

    var formattedDate: String {
        guard let d = ISO8601DateFormatter().date(from: reminder.date) else { return "-" }
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMMM yyyy"
        return fmt.string(from: d)
    }

    var formattedTime: String {
        guard let d = ISO8601DateFormatter().date(from: reminder.date) else { return "-" }
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
                    Text("Add photo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                    Text(reminder.notes?.isEmpty == false ? reminder.notes! : "No notes")
                        .foregroundColor(reminder.notes?.isEmpty == false ? .primary : .secondary)
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
                FormRowDisplay(label: "Repeat", value: reminder.repeatOption.capitalized)
                Divider().padding(.leading)
                FormRowDisplay(label: "Early Reminder", value: reminder.earlyReminder ?? "None")
                Divider().padding(.leading)
                FormRowDisplay(label: "Category", value: reminder.category ?? "None")

                // Progress
                if reminder.totalCount > 1 {
                    Divider().padding(.top, 8)
                    SectionHeader(title: "Progress")
                    FormRowDisplay(
                        label: "Completed",
                        value: "\(reminder.completedCount) / \(reminder.totalCount)"
                    )
                }

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
                    Task { await markDone() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isDone || reminder.isCompleted ? Color.green : Color.blue)
                            .frame(width: 32, height: 32)
                        if isMarking {
                            ProgressView().tint(.white).scaleEffect(0.7)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isMarking || isDone || reminder.isCompleted)
            }
        }
        .onAppear {
            isDone = reminder.isCompleted
        }
    }

    // MARK: - Mark Done
    private func markDone() async {
        guard let token = appState.token,
              let url = URL(string: "https://safe-one-backend.vercel.app/api/reminders/\(reminder.id)/done")
        else { return }

        isMarking = true
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let (_, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, http.statusCode == 200 {
            await MainActor.run {
                isDone = true
                isMarking = false
                onMarkDone?()
            }
        } else {
            await MainActor.run { isMarking = false }
        }
    }
}
