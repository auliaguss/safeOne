import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct Onboarding: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedRole: UserRole?
    @State private var currentNonce: String?
    @State private var pairingCode = ""

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

                    if selectedRole == .elder {
                        TextField("Enter pairing code", text: $pairingCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        Text("Ask your caregiver for the pairing code shown in their app.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else if selectedRole == .children {
                        Text("After sign-in, open Paired Elders in Profile to generate a code and share it with the elder.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        let nonce = Self.randomNonceString()
                        currentNonce = nonce
                        request.nonce = Self.sha256(nonce)
                    } onCompletion: { result in
                        guard let selectedRole else { return }
                        let nonce = currentNonce

                        switch result {
                        case .success(let authorization):
                            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                                appState.apiMessage = "Apple sign-in failed."
                                return
                            }

                            Task {
                                await appState.signInWithApple(
                                    credential: credential,
                                    role: selectedRole,
                                    nonce: nonce
                                )
                                if selectedRole == .elder {
                                    let joined = await appState.joinPairing(code: pairingCode)
                                    if !joined {
                                        appState.apiMessage = "Could not join pairing with the code you entered."
                                    }
                                } else if selectedRole == .children, appState.pairingCode == nil {
                                    _ = await appState.generatePairingCode()
                                }
                                currentNonce = nil
                            }
                        case .failure(let error):
                            appState.apiMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(maxWidth: 375)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(selectedRole == nil || (selectedRole == .elder && pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .opacity(selectedRole == nil || (selectedRole == .elder && pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.55 : 1.0)

#if DEBUG
                    Button {
                        guard let selectedRole else { return }
                        Task {
                            await appState.signInLocally(role: selectedRole)
                        }
                    } label: {
                        Text("Continue without Apple")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .disabled(selectedRole == nil)

                    Text("If Apple sign-in fails, use the local demo login to keep testing.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
#endif
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

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    Onboarding()
        .environmentObject(AppState())
}
