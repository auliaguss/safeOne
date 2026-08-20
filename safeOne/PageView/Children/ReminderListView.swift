//
//  ReminderListView.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import SwiftUI

private enum ListSheet: Identifiable {
    case create
    case edit(APIReminder)
    var id: String {
        switch self {
        case .create:      return "create"
        case .edit(let r): return "edit-\(r.id)"
        }
    }
}

struct ReminderListView: View {
    @EnvironmentObject var appState: AppState

    @State private var activeSheet: ListSheet? = nil
    @State private var showPastReminders = false

    // Backend data
    @State private var elders: [ElderItem] = []
    @State private var selectedElderId: String? = nil
    @State private var reminders: [APIReminder] = []
    @State private var isLoading = false
    @State private var initialLoadDone = false

    var activeReminders: [APIReminder] { reminders.filter { !$0.isPast } }
    var pastReminders: [APIReminder]   { reminders.filter { $0.isPast } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Text("Reminder Setup")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button(action: { activeSheet = .create }) {
                        ZStack {
                            Circle()
                                .fill(isLoading ? Color(.systemGray4) : Color.blue)
                                .frame(width: 36, height: 36)
                            if isLoading {
                                ProgressView().tint(.white).scaleEffect(0.6)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                // Elder Selector — same pill style as ElderSelectorView in Sharedcomponents
                if !elders.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(elders) { elder in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedElderId = elder.id
                                    }
                                    Task { await fetchReminders() }
                                } label: {
                                    Text(elder.name)
                                        .font(.subheadline)
                                        .fontWeight(selectedElderId == elder.id ? .semibold : .regular)
                                        .foregroundColor(selectedElderId == elder.id ? .white : .primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(selectedElderId == elder.id ? Color.black : Color(.systemGray5))
                                        )
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 12)
                }

                Divider()

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if reminders.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No reminders yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(reminders) { reminder in
                                Button { activeSheet = .edit(reminder) } label: {
                                    ReminderListRow(reminder: reminder, isPast: reminder.isPast)
                                }
                                .buttonStyle(PlainButtonStyle())
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                    }
                }
            }
            .background(
                ZStack {
                    Color.white
                    RadialGradient(
                        colors: [Color(red: 0, green: 218/255, blue: 195/255).opacity(0.15), Color.clear],
                        center: UnitPoint(x: 0.2, y: 0.1),
                        startRadius: 0,
                        endRadius: 400
                    )
                    RadialGradient(
                        colors: [Color(red: 0, green: 145/255, blue: 1.0).opacity(0.20), Color.clear],
                        center: UnitPoint(x: 0.8, y: 0.8),
                        startRadius: 0,
                        endRadius: 400
                    )
                }
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .create:
                    AddReminderView(initialElderId: selectedElderId, onSaved: {
                        Task { await fetchReminders() }
                    })
                    .environmentObject(appState)
                case .edit(let reminder):
                    AddReminderView(
                        initialElderId: reminder.elderId,
                        editingReminder: reminder,
                        onSaved: { Task { await fetchReminders() } }
                    )
                    .environmentObject(appState)
                }
            }
        }
        // Initial load
        .task {
            await fetchElders()
            initialLoadDone = true
        }
        // Refresh when navigating back from detail
        .onAppear {
            guard initialLoadDone else { return }
            Task { await fetchReminders() }
        }
    }

    // MARK: - Data

    private func fetchElders() async {
        guard let token = appState.token else { return }
        isLoading = true
        do {
            let decoded = try await ReminderRepository.fetchElders(token: token)
            await MainActor.run {
                elders = decoded
                if selectedElderId == nil { selectedElderId = decoded.first?.id }
                isLoading = false
            }
            await fetchReminders()
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func fetchReminders() async {
        guard let token = appState.token, let elderId = selectedElderId else { return }
        await MainActor.run { isLoading = true }
        do {
            let decoded = try await ReminderRepository.fetchReminders(elderId: elderId, token: token)
            await MainActor.run {
                // Discard if the user already switched to a different elder while this was in flight —
                // otherwise a slow response can overwrite the list with the wrong elder's reminders.
                guard elderId == selectedElderId else { return }
                reminders = decoded
                isLoading = false
            }
        } catch {
            await MainActor.run {
                guard elderId == selectedElderId else { return }
                isLoading = false
            }
        }
    }
}

// MARK: - Reminder List Row

struct ReminderListRow: View {
    let reminder: APIReminder
    var isPast: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ReminderImageView(
                imageName: reminder.imageName,
                size: 48,
                opacity: isPast ? 0.5 : 1.0,
                background: isPast ? Color(.systemGray5) : Color(.systemGray6),
                cornerRadius: 12
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isPast ? .secondary : .primary)
                Text(reminder.subtitleString)
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
