//
//  ElderCallingView.swift
//  safeOne
//
//  Created by Fransiskus Risky Gawahi on 29/05/26.
//
import SwiftUI
import Combine

struct ElderCallingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isConnected = false
    @State private var callDuration = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color(hex: "F2F2F7")
                .ignoresSafeArea()
            
            if !isConnected {
                //  STATUS 1: OUTGOING CALL
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .foregroundColor(.black)
                                .padding(.all, 12)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    Text("Calling for Help")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.bottom, 60)
                    
                    ZStack {
                        Circle()
                            .fill(Color(hex: "007AFF").opacity(0.15))
                            .frame(width: 240, height: 240)
                        Circle()
                            .fill(Color(hex: "007AFF"))
                            .frame(width: 180, height: 180)
                            .shadow(color: Color(hex: "007AFF").opacity(0.3), radius: 15, x: 0, y: 8)
                        Image(systemName: "phone.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("If this was a mistake,\nplease tap Cancel.")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 40)
                    
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(hex: "007AFF"))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            } else {
                // STATUS 2: CALLING PAGE ELDER (connected)
                VStack(spacing: 0) {
                    HStack {
                        Button(action: { isConnected = false }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                                .font(.title3)
                                .padding(.all, 12)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("Emergency Call")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            Text(formatTime(callDuration))
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .foregroundColor(.black)
                                .padding(.all, 12)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    ZStack {
                        LinearGradient(
                            colors: [Color(hex: "E8F3FF"), Color(hex: "C4E0E5")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .cornerRadius(28)
                        
                        VStack {
                            Text("🧔🏽👍🏼")
                                .font(.system(size: 110))
                        }
                    }
                    .padding(.all, 20)
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "phone.down.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 72, height: 72)
                            .background(Color(hex: "FF3B30"))
                            .clipShape(Circle())
                            .shadow(color: Color(hex: "FF3B30").opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation { isConnected = true }
            }
        }
        .onReceive(timer) { _ in
            if isConnected { callDuration += 1 }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let min = seconds / 60
        let sec = seconds % 60
        return String(format: "%02d:%02d", min, sec)
    }
}

#Preview {
    ElderCallingView()
}
