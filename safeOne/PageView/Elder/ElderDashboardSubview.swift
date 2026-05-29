//
//  Home.swift
//  safeOne
//
//  Created by Aulia Agus on 26/05/26.
//

import SwiftUI

struct ElderDashboardSubview: View {
    @State private var selectedReminder: ReminderItem? = nil
    
    //  list array data using new model structure
    let reminders = [
        ReminderItem(title: "Antibiotics", dosage: "1 Tablet", instruction: "After Meal", time: "09:00", statusText: "in 5 hours", imageName: "pill.fill"),
        ReminderItem(title: "Paracetamol", dosage: "1 Tablet", instruction: "After Meal", time: "18:00", statusText: "in 5 hours", imageName: "pill.fill")
    ]
    
    var body: some View {
        NavigationView{
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // ( Title Header dan Today's Events are the same as previous...)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Reminders")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        VStack(spacing: 12) {
                            ForEach(reminders) { item in
                                // Detecting finger taps on the medicine row to trigger the pop-up sheet.
                                Button(action: { selectedReminder = item }) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Color(hex: "E8F3FF").frame(width: 48, height: 48).cornerRadius(12)
                                            Image(systemName: item.imageName)
                                                .font(.title2).foregroundColor(Color(hex: "FF9500"))
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
                                    .background(Color.white)
                                    .cornerRadius(18)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            // Menampilkan pop-up detail obat saat baris di-klik sesuai mockup terakhirmu
            .sheet(item: $selectedReminder) { item in
                ElderReminderModalView(reminder: item)
            }
        }
        .navigationBarHidden(true)
    }
}
