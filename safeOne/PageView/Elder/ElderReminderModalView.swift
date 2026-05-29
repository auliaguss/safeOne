//
//  ElderReminderModalView.swift
//  safeOne
//
//  Created by Fransiskus Risky Gawahi on 29/05/26.
//

import SwiftUI

struct ElderReminderModalView: View {
    @Environment(\.dismiss) var dismiss
    let reminder: ReminderItem
    
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
                        Text("💊")
                            .font(.system(size: 110))
                    }
                    .padding(.bottom, 30)
                    
                    // Detail pill info
                    VStack(spacing: 8) {
                        Text(reminder.title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text(reminder.dosage)
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                        
                        Text(reminder.instruction)
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Blue time directory
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(Color(hex: "007AFF"))
                        Text(reminder.time)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "007AFF"))
                    }
                    .padding(.bottom, 30)
                    
                    // Group Action Buttons
                    VStack(spacing: 12) {
                        // Button Snooze on 10 mins
                        Button(action: { dismiss() }) {
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
                        Button(action: { dismiss() }) {
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
