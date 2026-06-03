import SwiftUI

struct Onboarding: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedRole: UserRole?

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

                VStack(spacing: 12) {
                    Text("Select your role")
                        .fontWeight(.semibold)

                    HStack(spacing: 12) {
                        roleButton(title: "Elder", systemImage: "heart.text.square.fill", role: .elder)
                        roleButton(title: "Caregiver", systemImage: "person.2.fill", role: .children)
                    }

                    Button {
                        guard let selectedRole else { return }
                        Task {
                            await appState.signInLocally(role: selectedRole)
                        }
                    } label: {
                        Text("Continue for Development")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedRole == nil)

                    Text("Authentication is skipped for now.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private func roleButton(title: String, systemImage: String, role: UserRole) -> some View {
        Button {
            selectedRole = role
        } label: {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)

                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundColor(selectedRole == role ? .white : .blue)
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(selectedRole == role ? Color.blue : Color.white.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.blue.opacity(0.8), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

#Preview {
    Onboarding()
        .environmentObject(AppState())
}
