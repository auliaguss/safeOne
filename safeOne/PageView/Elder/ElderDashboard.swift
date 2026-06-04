import SwiftUI
import AVFoundation

enum ElderTab {
    case dashboard
    case profile
}

struct ElderDashboard: View {
    @EnvironmentObject var appState: AppState
    @State private var showCallingScreen = false
    @State private var selectedReminder: Reminder?

    private var todaysReminders: [Reminder] {
        appState.remindersForCurrentUser(on: Date())
    }

    private var todaysEvents: [Reminder] {
        todaysReminders.filter { $0.category == .appointment }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F2F2F7")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Reminder")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Events")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            if todaysEvents.isEmpty {
                                Text("No events today.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            } else {
                                ForEach(todaysEvents) { reminder in
                                    ElderEventRow(reminder: reminder) {
                                        selectedReminder = reminder
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Reminders")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            VStack(spacing: 12) {
                                if todaysReminders.isEmpty {
                                    Text("No reminders today.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white)
                                        .cornerRadius(14)
                                } else {
                                    ForEach(todaysReminders) { reminder in
                                        ElderReminderRow(reminder: reminder) {
                                            selectedReminder = reminder
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()

                    Button(action: {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        showCallingScreen = true
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color(hex: "FF5E5B"))
                            .clipShape(Circle())
                            .shadow(color: Color(hex: "FF5E5B").opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    .accessibilityLabel("Emergency call")
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color(hex: "F2F2F7").opacity(0.96))
            }
            .sheet(item: $selectedReminder) { item in
                ElderReminderModalView(reminder: item)
            }
            .fullScreenCover(isPresented: $showCallingScreen) {
                ElderCallingView()
            }
            // TAMBAHKAN BLOK INI DI SINI
            .onAppear {
                // 1. Minta izin Mikrofon
                AVAudioApplication.requestRecordPermission { granted in
                    print("🎙️ Izin Mikrofon Elder: \(granted)")
                }
                
                // 2. Minta izin Kamera
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    print("📷 Izin Kamera Elder: \(granted)")
                }
            }
        }
        .navigationBarHidden(true)
    }
}


// MARK: - Row Views

struct ElderEventRow: View {
    let reminder: Reminder
    let onTap: () -> Void

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: reminder.date)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(reminder.imageName ?? "📅")
                    .font(.system(size: 32))
                    .frame(width: 52, height: 52)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(reminder.notes.isEmpty ? reminder.category.rawValue : reminder.notes)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(timeText)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "007AFF"))
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

struct ElderReminderRow: View {
    let reminder: Reminder
    let onTap: () -> Void

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: reminder.date)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ReminderImageView(imageName: reminder.imageName)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                    Text(timeText)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if reminder.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .opacity(reminder.isCompleted ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ElderDashboard()
}
