//
//  Onboarding.swift
//  safeOne
//
//  Created by Jason Ryan Susilo on 26/05/26.
//

import SwiftUI

struct Onboarding: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    Color.cyan.opacity(0.15),
                    Color.blue.opacity(0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // logo
            VStack {
                HStack(spacing: 8) {
                    
                    Image(systemName: "shield.checkered")
                    
                    Text("SafeOne+")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top, 60)
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.7), lineWidth: 5)
                        .frame(width: 180, height: 177)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.7), lineWidth: 3)
                        .frame(width: 320, height: 320)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.7), lineWidth: 3)
                        .frame(width: 500, height: 500)
                    
                    Text("👵🏻")
                        .font(.system(size: 50))
                        .frame(width: 177, height: 177)
                        .background(Color.cyan.opacity(0.2))
                        .clipShape(Circle())
                    
                    
                    Text("❤️")
                        .font(.system(size: 30))
                        .offset(x: 100, y: -230)
                    
                    Text("👨🏻‍🦱")
                        .font(.system(size: 45))
                        .padding(10)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .offset(x: -90, y: -230)

                    Text("💊")
                        .font(.system(size: 35))
                        .offset(x: -125, y: -90)
                    
                    Text("👨🏻‍🦱")
                        .font(.system(size: 45))
                        .padding(10)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .offset(x: 130, y: -105)

                    Text("⏰")
                        .font(.system(size: 30))
                        .offset(x: 90, y: 120)
                    
                    Text("👨🏻‍🦱")
                        .font(.system(size: 45))
                        .padding(10)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .offset(x: -90, y: 130)
                    
                }
                .frame(height: 400)
                
                Spacer()
                
                Text("What’s your role?")
                    .fontWeight(.semibold)
                
                Button {

                } label: {
                    Text("Elder")
                        .foregroundColor(.white)
                        .frame(width: 300)
                        .padding()
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                
                Button {

                } label: {
                    Text("Children/Caregiver")
                        .foregroundColor(.white)
                        .frame(width: 300)
                        .padding()
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

#Preview {
    Onboarding()
}
