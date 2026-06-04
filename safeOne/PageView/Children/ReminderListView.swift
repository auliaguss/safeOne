//
//  ReminderListView.swift
//  safeOne
//

import SwiftUI

struct ReminderListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddReminder = false
    @State private var showPastReminders = false
    @State private var reminders: [APIReminder] = []
    @State private var isLoading = false
    @State private var selectedElderId: String? = nil
    @State private var elders: [ElderItem] = []

    var activeReminders: [APIReminder] { reminders.filter { !$0.isPast } }
    var pastReminders: [APIReminder] { reminders.filter { $0.isPast } }

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
                                .fill(selectedElderId != nil ? Color.blue : Color(.systemGray4))
                                .frame(width: 36, height: 36)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(selectedElderId == nil)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                // Elder Selector
                if elders.isEmpty {
                    Text("Belum ada elder yang terhubung")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(elders) { elder in
                                Button {
                                    selectedElderId = elder.id
                                    Task { await fetchReminders() }
                                } label: {
                                    HStack(spacing: 6) {
                                        if let avatar = elder.avatar, !avatar.isEmpty {
                                            Text(avatar).font(.caption)
                                        }
                                        Text(elder.name)
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(selectedElderId == elder.id ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(selectedElderId == elder.id ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 12)
                }

                Divider()

                if isLoading {
                    Spacer()
                    ProgressView("Memuat reminders...")
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(activeReminders) { reminder in
                                NavigationLink(destination: ReminderDetailView(
                                    reminder: reminder,
                                    onMarkDone: { Task { await fetchReminders() } }
                                )) {
                                    ReminderListRow(reminder: reminder)
                                }
                                .buttonStyle(PlainButtonStyle())
                                Divider().padding(.leading, 72)
                            }

                            if activeReminders.isEmpty && selectedElderId != nil {
                                Text("Tidak ada reminder untuk hari ini")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 40)
                            }

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
                                ForEach(pastReminders) { reminder in
                                    ReminderListRow(reminder: reminder, isPast: true)
                                    Divider().padding(.leading, 72)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddReminder) {
                AddReminderView(elderId: selectedElderId, onSaved: {
                    Task { await fetchReminders() }
                })
                .environmentObject(appState)
            }
            .task {
                await fetchElders()
            }
        }
    }

    private func fetchElders() async {
        guard let token = appState.token,
              let url = URL(string: "https://safe-one-backend.vercel.app/api/users/me/elders")
        else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode([ElderItem].self, from: data)
        else { return }

        await MainActor.run {
            elders = decoded
            if selectedElderId == nil { selectedElderId = decoded.first?.id }
        }
        await fetchReminders()
    }

    private func fetchReminders() async {
        guard let token = appState.token, let elderId = selectedElderId else { return }

        let formatter = ISO8601DateFormatter()
        let today = formatter.string(from: Date())
        guard let encodedDate = today.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://safe-one-backend.vercel.app/api/reminders?elderId=\(elderId)&date=\(encodedDate)")
        else { return }

        isLoading = true
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let (data, _) = try? await URLSession.shared.data(for: request),
           let decoded = try? JSONDecoder().decode([APIReminder].self, from: data) {
            await MainActor.run {
                reminders = decoded
                isLoading = false
            }
        } else {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Models
struct ElderItem: Codable, Identifiable {
    let id: String
    let name: String
    let avatar: String?
}

struct APIReminder: Codable, Identifiable {
    let id: String
    let title: String
    let notes: String?
    let date: String
    let repeatOption: String
    let earlyReminder: String?
    let category: String?
    let isCompleted: Bool
    let completedCount: Int
    let totalCount: Int
    let imageName: String?

    var isPast: Bool {
        guard let d = ISO8601DateFormatter().date(from: date) else { return false }
        return d < Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, date
        case repeatOption  = "repeat_option"
        case earlyReminder = "early_reminder"
        case category
        case isCompleted   = "is_completed"
        case completedCount = "completed_count"
        case totalCount    = "total_count"
        case imageName     = "image_name"
    }
}

// MARK: - Reminder List Row
struct ReminderListRow: View {
    let reminder: APIReminder
    var isPast: Bool = false

    var subtitleString: String {
        guard let d = ISO8601DateFormatter().date(from: reminder.date) else { return "" }
        let fmt = DateFormatter()
        if reminder.repeatOption == "everyday" {
            fmt.dateFormat = "HH.mm"
            return "Everyday, \(fmt.string(from: d))"
        } else {
            fmt.dateFormat = "d MMM, HH.mm"
            return fmt.string(from: d)
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

            if reminder.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
    }
}
