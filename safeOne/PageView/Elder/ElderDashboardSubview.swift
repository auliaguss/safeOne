//
//  Home.swift
//  safeOne
//
//  Created by Aulia Agus on 26/05/26.
//

import SwiftUI

struct ElderDashboardSubview: View {
    @EnvironmentObject var appState: AppState
    var reminders: [APIReminder] = []
    @State private var selectedReminder: APIReminder? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Reminders")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.black)

                        if reminders.isEmpty {
                            Text("No reminders today")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(reminders) { item in
                                    Button(action: { selectedReminder = item }) {
                                        HStack(spacing: 16) {
                                            ReminderImageView(
                                                imageName: item.imageName,
                                                size: 48,
                                                background: Color(hex: "E8F3FF"),
                                                cornerRadius: 12
                                            )
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title).font(.body).fontWeight(.bold).foregroundColor(.black)
                                                if let notes = item.notes, !notes.isEmpty {
                                                    Text(notes).font(.caption).foregroundColor(.gray)
                                                }
                                                Text(item.timesText).font(.subheadline).foregroundColor(.gray)
                                            }
                                            Spacer()
                                            Text(item.statusText)
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
            .sheet(item: $selectedReminder) { item in
                ElderReminderModalView(reminder: item)
                    .environmentObject(appState)
            }
        }
        .navigationBarHidden(true)
    }
}
