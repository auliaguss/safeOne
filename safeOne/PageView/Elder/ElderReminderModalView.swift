//
//  ElderReminderModalView.swift
//  safeOne
//
//  Created by Fransiskus Risky Gawahi on 29/05/26.
//

import SwiftUI

struct ElderReminderModalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let reminder: Reminder

    private var reminderTime: String {
        let nextDate = reminder.nextOccurrence(after: Date()) ?? reminder.date
        return nextDate.formatted(.dateTime.hour().minute())
    }
    
    var body: some View {
        NavigationStack{
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Close-Cross button on top right
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.black)
                                .font(.title3)
                                .padding(.all, 12)
                                .background(Color(hex: "F2F2F7"))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    // Huge Circle pill image
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F2F2F7"))
                            .frame(width: 260, height: 260)
                        
                        //  placeholder icon/emoji
                        Text(reminder.imageName ?? "💊")
                            .font(.system(size: 110))
                    }
                    .padding(.bottom, 30)
                    
                    // Detail pill info
                    VStack(spacing: 8) {
                        Text(reminder.title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text(reminder.category == .none ? "Reminder" : reminder.category.rawValue)
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                        
                        Text(reminder.notes.isEmpty ? "No extra notes" : reminder.notes)
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Blue time directory
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(Color(hex: "007AFF"))
                        Text(reminderTime)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "007AFF"))
                    }
                    .padding(.bottom, 30)
                    
                    // Group Action Buttons
                    VStack(spacing: 12) {
                        // Button Snooze on 10 mins
                        Button(action: {
                            appState.snoozeReminder(reminder.id)
                            dismiss()
                        }) {
                            Text("Snooze on 10 mins")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(Color(hex: "007AFF"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(hex: "007AFF"), lineWidth: 1)
                                )
                        }
                        
                        // Button Done
                        Button(action: {
                            appState.acknowledgeReminder(reminder.id)
                            dismiss()
                        }) {
                            Text("Done")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "007AFF"))
                                .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
