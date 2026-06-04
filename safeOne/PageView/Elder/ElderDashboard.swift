//
//  ElderDashboard.swift
//  safeOne
//
//  Created by Fransiskus Risky Gawahi on 29/05/26.
//

import SwiftUI

enum ElderTab {
    case dashboard
    case profile
}

struct ElderDashboard: View {
    @EnvironmentObject var appState: AppState
    @State private var currentTab: ElderTab = .dashboard
    @State private var showCallingScreen = false
    @State private var selectedReminder: Reminder? = nil

    private var elder: Elder? {
        appState.selectedElder ?? appState.elders.first
    }

    private var todayReminders: [Reminder] {
        appState.todayReminders(for: elder)
    }

    private var todayAppointments: [Reminder] {
        todayReminders.filter { $0.category == .appointment }
    }

    private var todayCareReminders: [Reminder] {
        todayReminders.filter { $0.category != .appointment }
    }
    
    var body: some View {
        NavigationStack{
            ZStack {
                Color(hex: "F2F2F7")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // main content page
                    Group {
                        switch currentTab {
                        case .dashboard:
                            // main view for DASHBOARD ELDER
                            ScrollView {
                                VStack(alignment: .leading, spacing: 24) {
                                    
                                    // 1. Title Header
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Daily Reminder")
                                            .font(.system(size: 34, weight: .bold, design: .rounded))
                                            .foregroundColor(.black)
                                        Text(Date().formatted(.dateTime.weekday(.abbreviated).day().month(.wide).year()))
                                            .font(.system(.body, design: .rounded))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.top, 24)
                                    
                                    // 2. Today's Events Section
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Today's Events")
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundColor(.black)

                                        if let appointment = todayAppointments.first {
                                            Button(action: { selectedReminder = appointment }) {
                                                HStack(spacing: 16) {
                                                    ZStack {
                                                        Color(hex: "E8F3FF").frame(width: 48, height: 48).cornerRadius(12)
                                                        Text("👨‍⚕️").font(.title)

                                                    }

                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(appointment.title).font(.body).fontWeight(.semibold).foregroundColor(.black)
                                                        Text(displayTime(for: appointment)).font(.subheadline).foregroundColor(.gray)
                                                    }
                                                    Spacer()
                                                    Text("See Details")
                                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                                        .background(Color(hex: "3A86F5")).cornerRadius(10)
                                                }
                                                .padding(.all, 16)
                                                .background(Color.white).cornerRadius(18)
                                            }
                                        } else {
                                            emptyCard(text: "No appointments today")
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    
                                    // 3. Today's Reminders Section
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Today's Reminders")
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundColor(.black)

                                        if todayCareReminders.isEmpty {
                                            emptyCard(text: "No reminders scheduled today")
                                        } else {
                                            VStack(spacing: 12) {
                                                ForEach(todayCareReminders) { reminder in
                                                    Button(action: { selectedReminder = reminder }) {
                                                        HStack(spacing: 16) {
                                                            ZStack {
                                                                Color(hex: "E8F3FF").frame(width: 48, height: 48).cornerRadius(12)
                                                                Text(reminder.imageName ?? "💊").font(.title2)
                                                            }

                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text(reminder.title).font(.body).fontWeight(.bold).foregroundColor(.black)
                                                                Text(reminder.notes.isEmpty ? (reminder.category == .none ? "Reminder" : reminder.category.rawValue) : reminder.notes)
                                                                    .font(.caption).foregroundColor(.gray)
                                                                    .lineLimit(1)
                                                                Text(displayTime(for: reminder)).font(.subheadline).foregroundColor(.gray)
                                                            }
                                                            Spacer()
                                                            Text(statusText(for: reminder))
                                                                .font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "007AFF"))
                                                                .padding(.horizontal, 12).padding(.vertical, 6)
                                                                .background(Capsule().stroke(Color(hex: "007AFF"), lineWidth: 1))
                                                        }
                                                        .padding(.all, 16)
                                                        .background(Color.white).cornerRadius(18)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                            
                        case .profile:
                            // connect to file Profile() already brought in this folder PageView
                            ElderProfileView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // CUSTOM BOTTOM NAVIGATION BAR
                    HStack {
                        Spacer(minLength: 20)
                        
                        // floating SOS button
                        Button(action: {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                            showCallingScreen = true
                        }) {
                            Image(systemName: "phone.fill")
                                .font(.title2).foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(Color(hex: "FF5E5B")).clipShape(Circle())
                                .shadow(color: Color(hex: "FF5E5B").opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .background(Color(hex: "F2F2F7"))
                }
            }
            // MODAL OVERLAY while ROWS clicked / SOS clicked
            .sheet(item: $selectedReminder) { item in
                ElderReminderModalView(reminder: item)
                    .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $showCallingScreen) {
                ElderCallingView()
            }
        }
        .navigationBarHidden(true)
    }

    private func displayTime(for reminder: Reminder) -> String {
        let nextDate = reminder.nextOccurrence(after: Date()) ?? reminder.date
        return nextDate.formatted(.dateTime.hour().minute())
    }

    private func statusText(for reminder: Reminder) -> String {
        guard let nextDate = reminder.nextOccurrence(after: Date()) else {
            return "Done"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: nextDate, relativeTo: Date())
    }

    private func emptyCard(text: String) -> some View {
        HStack {
            Text(text)
                .font(.body)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.all, 16)
        .background(Color.white)
        .cornerRadius(18)
    }
}


#Preview {
    ElderDashboard()
        .environmentObject(AppState())
}
