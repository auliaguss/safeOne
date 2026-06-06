//
//  DashboardView.swift
//  ElderCareApp
//

import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    @State private var elders: [ElderItem] = []
    @State private var selectedElderId: String? = nil
    @State private var reminders: [APIReminder] = []
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {

                // Header — identical design, date now reflects selectedDate
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
                    Button(action: { showDatePicker = true }) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Elder Selector — same pill style as ElderSelectorView
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
                    .padding(.bottom, 16)
                }

                Divider()

                // Reminder list
                if isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if reminders.isEmpty {
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
                            ForEach(reminders) { reminder in
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
        // Date picker sheet
        .sheet(isPresented: $showDatePicker) {
            VStack(spacing: 0) {
                HStack {
                    Text("Select Date")
                        .font(.headline)
                    Spacer()
                    Button("Done") { showDatePicker = false }
                        .fontWeight(.semibold)
                }
                .padding()
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
            }
            .presentationDetents([.medium])
        }
        // Fetch only when the sheet closes (Done button or swipe-dismiss),
        // not on every date tap inside the picker.
        .onChange(of: showDatePicker) { _, isShowing in
            if !isShowing { Task { await fetchReminders() } }
        }
        .task {
            await fetchElders()
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
            let decoded = try await ReminderRepository.fetchReminders(elderId: elderId, date: selectedDate, token: token)
            await MainActor.run { reminders = decoded; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Dashboard Reminder Row — same design, uses APIReminder

struct DashboardReminderRow: View {
    let reminder: APIReminder

    var timeString: String { reminder.timesText }

    var body: some View {
        HStack(spacing: 12) {
            ReminderImageView(imageName: reminder.imageName, size: 48, cornerRadius: 12)

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

// MARK: - Status Badge — circular progress matching Image 4

struct StatusBadgeView: View {
    let reminder: APIReminder

    var body: some View {
        let done = reminder.completedCount
        let total = max(reminder.totalCount, 1)
        let complete = reminder.isCompleted || done >= total

        if complete {
            // Blue filled circle with checkmark
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        } else {
            // Circle outline: blue if any progress, gray if none
            ZStack {
                Circle()
                    .stroke(done > 0 ? Color.blue : Color(.systemGray4), lineWidth: 1.5)
                    .frame(width: 40, height: 40)
                Text("\(done)/\(total)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(done > 0 ? .blue : .secondary)
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
}
