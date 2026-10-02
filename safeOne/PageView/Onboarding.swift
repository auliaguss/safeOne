 //
//  Onboarding.swift
//  safeOne
//

import SwiftUI
import UIKit

struct Onboarding: View {
    var onComplete: (String) -> Void = { _ in }
    var skipExistingUserCheck: Bool = false
    @EnvironmentObject var appState: AppState
    @State private var navigateToElder = false
    @State private var navigateToChild = false
    @State private var isLoading = false
    @State private var isCheckingUser = true // Menandakan sedang cek user otomatis
    @State private var navigateToSetupProfile = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                RadialGradient(
                    colors: [
                        Color(red: 0, green: 218/255, blue: 195/255).opacity(0.20),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.2, y: 0.1),
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()
                RadialGradient(
                    colors: [
                        Color(red: 0, green: 145/255, blue: 1.0).opacity(0.25),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.8, y: 0.8),
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                VStack {
                    HStack(spacing: 8) {
                        Image("AppIconFlat")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        Text("Healder")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 30)

                    Spacer()

                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSinceReferenceDate

                        // Child avatars: 1 putaran per 12 detik (searah jarum jam)
                        let childAngle = (t / 12).truncatingRemainder(dividingBy: 1) * 2 * .pi

                        // Emojis: 1 putaran per 8 detik (berlawanan jarum jam)
                        let emojiAngle = -(t / 8).truncatingRemainder(dividingBy: 1) * 2 * .pi

                        let childRadius: CGFloat = 160
                        let emojiRadius: CGFloat = 250
                        let childBaseAngles: [Double] = [0, 2 * .pi / 3, 4 * .pi / 3]
                        let emojis: [(String, Double)] = [
                            ("❤️", .pi / 3),
                            ("💊", .pi),
                            ("⏰", 5 * .pi / 3)
                        ]

                        ZStack {
                            // Ring 1 — tengah
                            Circle()
                                .stroke(Color.white.opacity(0.7), lineWidth: 5)
                                .frame(width: 180, height: 177)
                            // Ring 2 — menengah
                            Circle()
                                .stroke(Color.white.opacity(0.7), lineWidth: 3)
                                .frame(width: 320, height: 320)
                            // Ring 3 — luar
                            Circle()
                                .stroke(Color.white.opacity(0.7), lineWidth: 3)
                                .frame(width: 500, height: 500)

                            // ── Elder avatar — DIAM di tengah ──
                            Image("avatar_elder")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .frame(width: 170, height: 170)
                                .background(Color.cyan.opacity(0.2))
                                .clipShape(Circle())

                            // ── Child avatars — orbit ring menengah ──
                            ForEach(childBaseAngles.indices, id: \.self) { i in
                                let angle = childAngle + childBaseAngles[i]
                                Image("avatar_child")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 55, height: 55)
                                    .frame(width: 80, height: 80)
                                    .background(Color.white.opacity(0.8))
                                    .clipShape(Circle())
                                    .offset(
                                        x: childRadius * cos(angle),
                                        y: childRadius * sin(angle)
                                    )
                            }

                            // ── Emojis — orbit ring luar, berlawanan arah ──
                            ForEach(emojis.indices, id: \.self) { i in
                                let angle = emojiAngle + emojis[i].1
                                Text(emojis[i].0)
                                    .font(.system(size: 38))
                                    .offset(
                                        x: emojiRadius * cos(angle),
                                        y: emojiRadius * sin(angle)
                                    )
                            }
                        }
                    }
                    .frame(height: 400)

                    Spacer()

                    // AREA BAWAH: Loading Pengecekan atau Tampilan Tombol
                    if isCheckingUser {
                        ProgressView("Checking user data...")
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
                                Task { await handleRoleSelection(role: "elder") }
                            } label: {
                                Text(appState.text(
                                    isLoading ? "Memuat..." : "Lansia",
                                    isLoading ? "Loading..." : "Elder"
                                ))
                                    .foregroundColor(.white)
                                    .frame(width: 300)
                                    .padding()
                                    .background(isLoading ? Color.gray : Color.black)
                                    .clipShape(Capsule())
                            }
                            .disabled(isLoading)

                            // Tombol Children
                            Button {
                                Task { await handleRoleSelection(role: "child") }
                            } label: {
                                Text(appState.text(
                                    isLoading ? "Memuat..." : "Anak/Pendamping",
                                    isLoading ? "Loading..." : "Children/Caregiver"
                                ))
                                    .foregroundColor(.white)
                                    .frame(width: 300)
                                    .padding()
                                    .background(isLoading ? Color.gray : Color.black)
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
            .navigationDestination(isPresented: $navigateToSetupProfile) {
                SetupProfileView()
                    .environmentObject(appState)
            }
        }
        .navigationBarBackButtonHidden(true)
        // Jalankan pengecekan otomatis saat layar muncul
        .task {
            if skipExistingUserCheck {
                isCheckingUser = false
            } else {
                await checkExistingUser()
            }
        }
    }

    private func handleRoleSelection(role: String) async {
        // Setelah logout, pilihan role harus selalu dikirim ke dev-login.
        // check-user hanya mengembalikan role lama dan dapat mencegah user
        // berpindah dari child ke elder (atau sebaliknya).
        await performDevLogin(role: role)
    }

    // MARK: - Check Existing User (Otomatis)
    private func checkExistingUser() async {
        guard let url = URL(string: "\(AppConfig.baseURL)/auth/check-user") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10   // fail fast — show error instead of hanging

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
                            isCheckingUser = false

                            let isProfileComplete = !(userName.isEmpty) && !(userDict["avatar"] as? String ?? "").isEmpty

                            if isProfileComplete {
                                if userRole == "elder" {
                                    navigateToElder = true
                                } else {
                                    navigateToChild = true
                                }
                            } else {
                                navigateToSetupProfile = true
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
                errorMessage = appState.text("Gagal terhubung saat mengecek pengguna.", "Unable to connect while checking the user.")
            }
        }
    }

    // MARK: - Dev Login (Hanya dipanggil jika user belum ada & menekan tombol)
    private func performDevLogin(role: String) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(AppConfig.baseURL)/auth/dev-login") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let devUserId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let dummyName = role == "elder" ? "Elder" : "Caregiver"

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
                        errorMessage = appState.text("Gagal membaca respons dari server.", "Unable to read the server response.")
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

                    let isProfileComplete = !(userName.isEmpty) && !(userDict["avatar"] as? String ?? "").isEmpty

                    if isProfileComplete {
                        if userRole == "elder" {
                            navigateToElder = true
                        } else {
                            navigateToChild = true
                        }
                    } else {
                        navigateToSetupProfile = true
                    }
                }

            } else {
                let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMsg = errorResponse?["error"] as? String ?? "Terjadi kesalahan server"
                await MainActor.run {
                    isLoading = false
                    errorMessage = appState.text("Gagal: \(errorMsg)", "Failed: \(errorMsg)")
                }
            }

        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = appState.text("Gagal terhubung ke server.", "Unable to connect to the server.")
            }
        }
    }
}

#Preview {
    Onboarding()
        .environmentObject(AppState())
}
