//
//  Profile.swift
//  safeOne
//
//  Created by Aulia Agus on 26/05/26.
//

import SwiftUI

struct Profile: View {
    @State private var selectedSound = "Default"
    @State private var isHapticsEnabled = true
    @State private var isTextToSpeechEnabled = true
    
    let soundOptions = ["Default", "Loud Alert", "Soft Chime", "None"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // HEADER TITLE
                Text("Profile")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.top, 16)
                
                // ELDER CARD INFO
                HStack(spacing: 16) {
                    // Avatar Placeholder blue circle
                    ZStack {
                        Circle()
                            .fill(Color(hex: ""))
                            .frame(width: 64, height: 64)
                        Text("👵🏻") // Represent visual Memoji Sukarni
                            .font(.system(size: 40))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sukarni")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        Text("Elder")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.all, 16)
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 24)
                
                // SECTION: ACCOUNT
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                    
                    VStack(spacing: 0) {
                        NavigationRowLink(title: "Elder Lists")
                        Divider().padding(.leading, 16)
                        NavigationRowLink(title: "Connected Devices")
                        Divider().padding(.leading, 16)
                        NavigationRowLink(title: "Health Information")
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                }
                .padding(.horizontal, 24)
                
                // SECTION: NOTIFICATION
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notification")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                    
                    VStack(spacing: 0) {
                        // Sound Picker Row
                        HStack {
                            Text("Sounds")
                                .font(.system(size: 17, weight: .regular, design: .rounded))
                                .foregroundColor(.black)
                            Spacer()
                            Picker("", selection: $selectedSound) {
                                ForEach(soundOptions, id: \.self) { option in
                                    Text(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        Divider().padding(.leading, 16)
                        
                        // Haptics Toggle Row
                        Toggle(isOn: $isHapticsEnabled) {
                            Text("Haptics")
                                .font(.system(size: 17, weight: .regular, design: .rounded))
                                .foregroundColor(.black)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "34C759")))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        Divider().padding(.leading, 16)
                        
                        // Text To Speech Toggle Row
                        Toggle(isOn: $isTextToSpeechEnabled) {
                            Text("Text To Speech")
                                .font(.system(size: 17, weight: .regular, design: .rounded))
                                .foregroundColor(.black)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "34C759")))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                }
                .padding(.horizontal, 24)
                
                // SECTION: GENERAL
                VStack(alignment: .leading, spacing: 8) {
                    Text("General")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                    
                    VStack(spacing: 0) {
                        NavigationRowLink(title: "Emergency Services")
                        Divider().padding(.leading, 16)
                        NavigationRowLink(title: "Data & Privacy")
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100) //
            }
        }
        .background(Color(hex: "F2F2F7").ignoresSafeArea())
    }
}

// COMPONENT: NAVIGATION ROW UTK LIST STANDARD
struct NavigationRowLink: View {
    let title: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    Profile()
}
