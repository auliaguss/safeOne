//
//  ProfileView.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import SwiftUI

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var hapticsEnabled: Bool = true
    @State private var textToSpeechEnabled: Bool = true
    @State private var goToOnboarding = false
    @State private var soundsDefault: String = "Default"
    @State private var alertsValue: String = "Elders missed 1 reminder"
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Header
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 50, height: 50)
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bowo Prabu")
                                .font(.headline)
                            Text("Children")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Account
                Section("Account") {
                    NavigationLink("Elder Lists") {
                        ElderListView()
                    }
                    
                }
                
                // Notification
                Section("Notification") {
                    
                                    
                    HStack {
                        Text("Alerts")
                        Spacer()
                        Text(alertsValue)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // General
                Section("General") {
                    NavigationLink("Emergency Services") {
                        Text("Emergency Services")
                            .navigationTitle("Emergency Services")
                    }
                    NavigationLink("Data & Privacy") {
                        Text("Data & Privacy")
                            .navigationTitle("Data & Privacy")
                    }
                    
                }
                Button {
                    goToOnboarding = true
                } label: {
                    Text("Logout")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(16)
                }
                .padding()
            }
            .navigationDestination(isPresented: $goToOnboarding) {
                Onboarding()
            }
            
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Elder List View (Account > Elder Lists)
struct ElderListView: View {
    @EnvironmentObject var appState: AppState
    @State private var elders: [BackendElder] = []
    @State private var isLoading = false
    @State private var showAddElder = false
    @State private var otpCode = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                ForEach(elders) { elder in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBlue).opacity(0.15))
                                .frame(width: 44, height: 44)
                            Text(String(elder.name.prefix(1)))
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(elder.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Elder")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            await removeElder(elders[index].id)
                        }
                    }
                }
            }
        }
        .navigationTitle("Elder Lists")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddElder = true }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .alert("Add Elder via OTP", isPresented: $showAddElder) {
            TextField("Enter OTP Code", text: $otpCode)
                .keyboardType(.numberPad)
            Button("Add") {
                Task { await verifyOtp() }
            }
            Button("Cancel", role: .cancel) { otpCode = "" }
        } message: {
            if let error = errorMessage {
                Text(error)
            } else {
                Text("Enter the OTP code from the elder's device.")
            }
        }
        .onAppear {
            Task { await fetchElders() }
        }
    }

    // MARK: - Fetch Elders
    private func fetchElders() async {
        guard let token = appState.token,
              let url = URL(string: "https://safe-one-backend.vercel.app/api/users/me/elders")
        else {
            print("❌ Token atau URL nil")
            return
        }

        isLoading = true
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Print raw response
            print("📡 Status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            print("📡 Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
            
            let decoded = try JSONDecoder().decode([BackendElder].self, from: data)
            await MainActor.run {
                elders = decoded
                isLoading = false
                print("✅ Elders loaded: \(decoded.count)")
            }
        } catch {
            await MainActor.run { isLoading = false }
            print("❌ Fetch elders error: \(error)")
        }
    }

    // MARK: - Remove Elder
    private func removeElder(_ elderId: String) async {
        guard let token = appState.token,
              let url = URL(string: "https://safe-one-backend.vercel.app/api/users/me/elders/\(elderId)")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                await MainActor.run {
                    elders.removeAll { $0.id == elderId }
                }
            }
        } catch {
            print("❌ Remove elder error: \(error)")
        }
    }

    // MARK: - Verify OTP
    private func verifyOtp() async {
        guard let token = appState.token,
              let url = URL(string: "https://safe-one-backend.vercel.app/api/otp/verify")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["code": otpCode])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 200 {
                await MainActor.run {
                    otpCode = ""
                    errorMessage = nil
                }
                await fetchElders() // Refresh list
            } else {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let msg = json?["error"] as? String ?? "Invalid OTP code"
                await MainActor.run {
                    errorMessage = msg
                    otpCode = ""
                }
            }
        } catch {
            await MainActor.run { errorMessage = "Network error. Try again." }
        }
    }
}

// MARK: - Model
struct BackendElder: Codable, Identifiable {
    let id: String
    let name: String
    let avatar: String?
    let connectedSince: String?

    enum CodingKeys: String, CodingKey {
        case id, name, avatar
        case connectedSince = "connected_since"
    }
}

#Preview {
    ProfileView()
}
