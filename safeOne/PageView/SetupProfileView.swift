//
//  SetupProfileView.swift
//  safeOne
//
//  Created by Ivan Yuantama Pradipta on 05/06/26.
//


import SwiftUI

struct SetupProfileView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var name: String = ""
    @State private var selectedAvatar: String = "😊"
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var navigateToElder = false
    @State private var navigateToChild = false

    let avatarOptions = ["😊", "👦", "👧", "👨", "👩", "🧑", "👴", "👵", "🧓", "🙂"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                RadialGradient(
                    colors: [Color(red: 0, green: 218/255, blue: 195/255).opacity(0.15), Color.clear],
                    center: UnitPoint(x: 0.2, y: 0.1),
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()
                RadialGradient(
                    colors: [Color(red: 0, green: 145/255, blue: 1.0).opacity(0.20), Color.clear],
                    center: UnitPoint(x: 0.8, y: 0.8),
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Back button
                    HStack {
                        Button(action: { /* dismiss jika perlu */ }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .padding(12)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer().frame(height: 24)

                    // Title
                    VStack(spacing: 6) {
                        Text("Set up")
                            .font(.system(size: 34, weight: .bold))
                        Text("your profile")
                            .font(.system(size: 34, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Spacer().frame(height: 40)

                    // Avatar Besar
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 120, height: 120)
                        Text(selectedAvatar)
                            .font(.system(size: 64))
                    }

                    Spacer().frame(height: 20)

                    // Grid Avatar Pilihan
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(avatarOptions, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 30))
                                .frame(width: 52, height: 52)
                                .background(
                                    selectedAvatar == emoji
                                    ? Color.blue.opacity(0.2)
                                    : Color.white.opacity(0.8)
                                )
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(
                                        selectedAvatar == emoji ? Color.blue : Color.clear,
                                        lineWidth: 2
                                    )
                                )
                                .onTapGesture { selectedAvatar = emoji }
                        }
                    }
                    .padding(.horizontal, 40)

                    Spacer().frame(height: 32)

                    // Name Field
                    TextField("Name", text: $name)
                        .font(.system(size: 16))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.horizontal, 32)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }

                    Spacer()

                    // Tombol Continue
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        ZStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Continue")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            name.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.gray
                            : Color.blue
                        )
                        .clipShape(Capsule())
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToElder) {
                HealthInfoView(mode: .onboarding)
                    .environmentObject(appState)
            }
            .navigationDestination(isPresented: $navigateToChild) {
                ContentView(appState: _appState)
            }
        }
    }

    private func saveProfile() async {
        guard let token = appState.token,
              let url = URL(string: "https://safe-one-backend.vercel.app/api/users/me")
        else { return }

        isSaving = true
        errorMessage = nil

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "name": name.trimmingCharacters(in: .whitespaces),
            "avatar": selectedAvatar
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                await MainActor.run {
                    errorMessage = appState.text("Gagal menyimpan. Coba lagi.", "Failed to save. Try again.")
                    isSaving = false
                }
                return
            }

            await MainActor.run {
                if let user = appState.currentUser {
                    let updated = CurrentUser(
                        id: user.id,
                        name: json["name"] as? String ?? name,
                        role: user.role,
                        avatar: json["avatar"] as? String ?? selectedAvatar
                    )
                    appState.currentUser = updated
                    if let encoded = try? JSONEncoder().encode(updated) {
                        UserDefaults.standard.set(encoded, forKey: "current_user")
                    }
                }
                isSaving = false
                if appState.currentUser?.role == "elder" {
                    navigateToElder = true
                } else {
                    navigateToChild = true
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = appState.text("Gagal terhubung ke server.", "Unable to connect to the server.")
                isSaving = false
            }
        }
    }
}

#Preview {
    SetupProfileView()
        .environmentObject(AppState())
}
