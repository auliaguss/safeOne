import AuthenticationServices
import CryptoKit
import Security
import SwiftUI
import UIKit

struct Onboarding: View {
    var onComplete: (String) -> Void = { _ in }
    @EnvironmentObject var appState: AppState

    @State private var navigateToElder = false
    @State private var navigateToChild = false
    @State private var isLoading = false
    @State private var isCheckingUser = true // Menandakan sedang cek user otomatis
    @State private var errorMessage: String? = nil
    @State private var selectedRole: UserRole?
    @State private var currentNonce: String?

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
                    .disabled(selectedRole == nil)
                    .opacity(selectedRole == nil ? 0.55 : 1.0)

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
        NavigationStack {
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

                    // AREA BAWAH: Loading Pengecekan atau Tampilan Tombol
                    if isCheckingUser {
                        ProgressView("Mengecek data pengguna...")
                            .padding(.bottom, 50)
                    } else {
                        VStack(spacing: 15) {
                            Text("What's your role?")
                                .fontWeight(.semibold)

                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            // Tombol Elder
                            Button {
                                Task { await performDevLogin(role: "elder") }
                            } label: {
                                Text(isLoading ? "Loading..." : "Elder")
                                    .foregroundColor(.white)
                                    .frame(width: 300)
                                    .padding()
                                    .background(isLoading ? Color.gray : Color.blue)
                                    .clipShape(Capsule())
                            }
                            .disabled(isLoading)

                            // Tombol Children
                            Button {
                                Task { await performDevLogin(role: "child") }
                            } label: {
                                Text(isLoading ? "Loading..." : "Children/Caregiver")
                                    .foregroundColor(.white)
                                    .frame(width: 300)
                                    .padding()
                                    .background(isLoading ? Color.gray : Color.blue)
                                    .clipShape(Capsule())
                            }
                            .disabled(isLoading)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToElder) {
                ElderContentView(appState: _appState)
            }
            .navigationDestination(isPresented: $navigateToChild) {
                ContentView(appState: _appState)
            }
        }
        .navigationBarBackButtonHidden(true)
        // Jalankan pengecekan otomatis saat layar muncul
        .task {
            await checkExistingUser()
        }
    }

    // MARK: - Check Existing User (Otomatis)
    private func checkExistingUser() async {
        guard let url = URL(string: "http://safe-one-backend.vercel.app/api/auth/check-user") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let devUserId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let body: [String: Any] = ["devUserId": devUserId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let exists = json["exists"] as? Bool {
                
                if exists {
                    // Jika user sudah ada, parse data dan langsung masuk
                    if let token = json["token"] as? String,
                       let userDict = json["user"] as? [String: Any],
                       let userId = userDict["id"] as? String,
                       let userName = userDict["name"] as? String,
                       let userRole = userDict["role"] as? String {
                        
                        let user = CurrentUser(id: userId, name: userName, role: userRole, avatar: userDict["avatar"] as? String)
                        
                        await MainActor.run {
                            appState.saveSession(token: token, user: user)
                            if userRole == "elder" {
                                navigateToElder = true
                            } else {
                                navigateToChild = true
                            }
                        }
                    }
                } else {
                    // Jika belum ada, hilangkan loading dan munculkan tombol
                    await MainActor.run { isCheckingUser = false }
                }
            } else {
                await MainActor.run { isCheckingUser = false }
            }
        } catch {
            await MainActor.run {
                isCheckingUser = false
                errorMessage = "Gagal terhubung saat mengecek user."
            }
        }
    }

    // MARK: - Dev Login (Hanya dipanggil jika user belum ada & menekan tombol)
    private func performDevLogin(role: String) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "http://safe-one-backend.vercel.app/api/auth/dev-login") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let devUserId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let dummyName = role == "elder" ? "Opa/Oma" : "Caregiver"

        let body: [String: Any] = [
            "devUserId": devUserId,
            "name": dummyName,
            "role": role
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 200 {
                guard
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let token = json["token"] as? String,
                    let userDict = json["user"] as? [String: Any],
                    let userId = userDict["id"] as? String,
                    let userName = userDict["name"] as? String,
                    let userRole = userDict["role"] as? String // Role asli dari database
                else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Gagal membaca response dari server."
                    }
                    return
                }
                
                print("✅ Token didapat: \(token)")

                let user = CurrentUser(
                    id: userId,
                    name: userName,
                    role: userRole,
                    avatar: userDict["avatar"] as? String
                )

                await MainActor.run {
                    appState.saveSession(token: token, user: user)
                    isLoading = false
                    
                    // Gunakan userRole (data asli backend) untuk menentukan navigasi
                    if userRole == "elder" {
                        navigateToElder = true
                    } else {
                        navigateToChild = true
                    }
                }

            } else {
                let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMsg = errorResponse?["error"] as? String ?? "Terjadi kesalahan server"
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Gagal: \(errorMsg)"
                }
            }

        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Gagal terhubung ke server."
            }
        }
    }
}

#Preview {
    Onboarding()
        .environmentObject(AppState())
}
