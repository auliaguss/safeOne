import SwiftUI

struct ReminderListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddReminder = false
    @State private var showPairingSheet = false
    @State private var pairingCode = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Reminder")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        if needsPairing {
                            showPairingSheet = true
                        } else {
                            showAddReminder = true
                        }
                    }) {
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

                ElderSelectorView()
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                Divider()

                List {
                    ForEach(currentReminders) { reminder in
                        NavigationLink(destination: ReminderDetailView(reminder: reminder)) {
                            ReminderListRow(reminder: reminder)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await appState.deleteReminders(ids: [reminder.id])
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    if currentReminders.isEmpty {
                        Text(appState.selectedElder == nil ? "Pair with an elder before adding reminders." : "No reminders for this elder.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddReminder) {
                AddReminderView()
            }
            .sheet(isPresented: $showPairingSheet) {
                pairingSheet
            }
            .task {
                await appState.loadPairings()
                await appState.loadElders()
                await appState.loadReminders(userID: appState.selectedElder?.id)
            }
            .onChange(of: appState.selectedElderIndex) {
                Task {
                    await appState.loadReminders(userID: appState.selectedElder?.id)
                }
            }
        }
    }

    private var currentReminders: [Reminder] {
        appState.reminders.filter {
            !$0.isPast && $0.elderID == appState.selectedElder?.id
        }
    }

    private var needsPairing: Bool {
        appState.session?.user.role == .children && appState.selectedElder == nil
    }

    private var pairingSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter the code shown on the elder device to connect their account.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Pairing code", text: $pairingCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if let apiMessage = appState.apiMessage {
                    Text(apiMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        let joined = await appState.joinPairing(code: pairingCode)
                        if joined {
                            pairingCode = ""
                            showPairingSheet = false
                            await appState.loadPairings()
                            await appState.loadElders()
                            await appState.loadReminders(userID: appState.selectedElder?.id)
                        }
                    }
                } label: {
                    Text("Connect Elder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1.0)
            }
            .padding()
            .navigationTitle("Pairing")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showPairingSheet = false }
                }
            }
        }
    }
}

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
            ReminderImageView(imageName: reminder.imageName)
                .opacity(isPast ? 0.5 : 1.0)

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
