//
//  ElderDashboardSubview.swift
//  safeOne
//
//  Created by Fransiskus Risky Gawahi on 29/05/26.
//

import SwiftUI
import AVFoundation

enum ElderTab {
    case dashboard
    case profile
}

struct ElderDashboard: View {
    @State private var currentTab: ElderTab = .dashboard
    @State private var showCallingScreen = false
    @State private var selectedReminder: ReminderItem? = nil
    
    // Data list array medicine reminder for elder
    let reminders = [
        ReminderItem(title: "Antibiotics", dosage: "1 Tablet", instruction: "After Meal", time: "18:00", statusText: "in 5 hours", imageName: "pill.fill"),
        ReminderItem(title: "Paracetamol", dosage: "1 Tablet", instruction: "After Meal", time: "18:00", statusText: "in 5 hours", imageName: "pill.fill")
    ]
    
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
                                        Text("Mon, 25 May 2026")
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
                                        
                                        HStack(spacing: 16) {
                                            ZStack {
                                                Color(hex: "E8F3FF").frame(width: 48, height: 48).cornerRadius(12)
                                                Text("👨‍⚕️").font(.title)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Doctor Appointment").font(.body).fontWeight(.semibold).foregroundColor(.black)
                                                Text("14.00").font(.subheadline).foregroundColor(.gray)
                                            }
                                            Spacer()
                                            Button(action: {}) {
                                                Text("See Details")
                                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                                    .background(Color(hex: "3A86F5")).cornerRadius(10)
                                            }
                                        }
                                        .padding(.all, 16)
                                        .background(Color.white).cornerRadius(18)
                                    }
                                    .padding(.horizontal, 24)
                                    
                                    // 3. Today's Reminders Section
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Today's Reminders")
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundColor(.black)
                                        
                                        VStack(spacing: 12) {
                                            ForEach(reminders) { item in
                                                Button(action: { selectedReminder = item }) {
                                                    HStack(spacing: 16) {
                                                        ZStack {
                                                            Color(hex: "E8F3FF").frame(width: 48, height: 48).cornerRadius(12)
                                                            Image(systemName: item.imageName).font(.title2).foregroundColor(Color(hex: "FF9500"))
                                                        }
                                                        
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(item.title).font(.body).fontWeight(.bold).foregroundColor(.black)
                                                            Text(item.instruction).font(.caption).foregroundColor(.gray)
                                                            Text(item.time).font(.subheadline).foregroundColor(.gray)
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


#Preview {
    ElderDashboard()
}
