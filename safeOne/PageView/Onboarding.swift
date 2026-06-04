import SwiftUI
import UIKit

struct Onboarding: View {
    @EnvironmentObject var appState: AppState

    @State private var isLoading = false
    @State private var isCheckingUser = true
    @State private var errorMessage: String? = nil

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
        .task {
            await checkExistingUser()
        }
    }

    // MARK: - Check Existing User

    private func checkExistingUser() async {
        // Skip auto-sign-in if the user explicitly logged out this session.
        guard !appState.didExplicitlyLogOut else {
            isCheckingUser = false
            return
        }

        guard let url = URL(string: "http://safe-one-backend.vercel.app/api/auth/check-user") else {
            isCheckingUser = false
            return
        }

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
               let exists = json["exists"] as? Bool,
               exists,
               let token = json["token"] as? String,
               let userDict = json["user"] as? [String: Any],
               let userId = userDict["id"] as? String,
               let userName = userDict["name"] as? String,
               let userRole = userDict["role"] as? String {

                let user = CurrentUser(
                    id: userId,
                    name: userName,
                    role: userRole,
                    avatar: userDict["avatar"] as? String
                )

                appState.saveSession(token: token, user: user)
                await postLoginSetup(role: userRole)
                // safeOneApp switches view automatically when isLoggedIn becomes true
            } else {
                isCheckingUser = false
            }
        } catch {
            isCheckingUser = false
            errorMessage = "Connection failed while checking user."
        }
    }

    // MARK: - Dev Login

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
        let body: [String: Any] = ["devUserId": devUserId, "name": dummyName, "role": role]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String,
               let userDict = json["user"] as? [String: Any],
               let userId = userDict["id"] as? String,
               let userName = userDict["name"] as? String,
               let userRole = userDict["role"] as? String {

                let user = CurrentUser(
                    id: userId,
                    name: userName,
                    role: userRole,
                    avatar: userDict["avatar"] as? String
                )

                appState.saveSession(token: token, user: user)
                await postLoginSetup(role: userRole)
                isLoading = false
                // safeOneApp switches view automatically when isLoggedIn becomes true

            } else {
                let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let msg = errorResponse?["error"] as? String ?? "Server error"
                isLoading = false
                errorMessage = "Failed: \(msg)"
            }

        } catch {
            isLoading = false
            errorMessage = "Connection failed."
        }
    }

    // MARK: - Post-Login Setup

    private func postLoginSetup(role: String) async {
        if role == "child" {
            appState.startPolling()
            await appState.loadElders()
        }
        await appState.loadDashboardReminders(for: Date())
    }
}

#Preview {
    Onboarding()
        .environmentObject(AppState())
}
