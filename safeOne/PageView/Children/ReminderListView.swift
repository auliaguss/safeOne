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
                    Text("Reminder")
                        .font(.headline)
                    Spacer()
                    Button(action: { activeSheet = .create }) {
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
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(activeReminders) { reminder in
                                Button { activeSheet = .edit(reminder) } label: {
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
                                ForEach(pastReminders) { reminder in
                                    Button { activeSheet = .edit(reminder) } label: {
                                        ReminderListRow(reminder: reminder, isPast: true)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                    }
                }
            }
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
        do {
            let decoded = try await ReminderRepository.fetchReminders(elderId: elderId, token: token)
            await MainActor.run { reminders = decoded }
        } catch {}
    }
}

// MARK: - Reminder List Row

struct ReminderListRow: View {
    let reminder: APIReminder
    var isPast: Bool = false

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
