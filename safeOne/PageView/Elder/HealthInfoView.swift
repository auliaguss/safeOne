import SwiftUI

struct HealthInfoView: View {
    enum Mode { case onboarding, edit }
    let mode: Mode

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var dateOfBirth: Date = Calendar.current.date(
        from: DateComponents(year: 1960, month: 1, day: 1)) ?? Date()
    @State private var hasDOB = false
    @State private var showDatePicker = false
    @State private var bloodType = ""
    @State private var medicalConditions = ""
    @State private var allergies = ""
    @State private var insuranceProvider = ""
    @State private var policyNumber = ""
    @State private var additionalInsuranceInfo = ""
    @State private var medicalHistory = ""

    @State private var navigateToMain = false
    @State private var isSaving = false
    @State private var isLoadingData = false

    private let bloodTypeOptions = ["A", "B", "AB", "O", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]

    private var dobLabel: String {
        guard hasDOB else { return "Not set" }
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: dateOfBirth)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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

            // Scrollable content
            VStack(spacing: 0) {
                if mode == .onboarding { onboardingHeader }

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        dobRow
                        bloodTypeRow
                        fieldSection("Medical Conditions",
                                     text: $medicalConditions,
                                     placeholder: "e.g., High Blood Pressure, Asthma")
                        fieldSection("Allergies",
                                     text: $allergies,
                                     placeholder: "e.g., Penicillin, Peanuts, Shellfish")
                        insuranceGroup
                        fieldSection("Medical History (Optional)",
                                     text: $medicalHistory,
                                     placeholder: "e.g., Asthma hospitalization (2023)")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, mode == .onboarding ? 164 : 120)
                }
            }

            // Bottom buttons overlay
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.white.opacity(0), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 32)
                .allowsHitTesting(false)

                VStack(spacing: 12) {
                    if mode == .onboarding {
                        Button("Set Up Later") { navigateToMain = true }
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 1))
                    }
                    Button { Task { await saveAction() } } label: {
                        ZStack {
                            if isSaving { ProgressView().tint(.white) }
                            else {
                                Text(mode == .onboarding ? "Continue" : "Save")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: mode == .onboarding ? 60 : 16))
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .background(Color.white)
            }
        }
        .overlay {
            if isLoadingData {
                ZStack {
                    Color.white.opacity(0.7).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
        .navigationBarHidden(mode == .onboarding)
        .navigationTitle(mode == .edit ? "Health Information" : "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToMain) {
            ElderContentView(appState: _appState)
        }
        .sheet(isPresented: $showDatePicker) { dobPickerSheet }
        .task { if mode == .edit { await loadHealthInfo() } }
    }

    // MARK: - Onboarding header

    private var onboardingHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
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

            VStack(spacing: 8) {
                Text("Health Information")
                    .font(.system(size: 28, weight: .bold))
                Text("Add health details to personalize the care\nexperience. You can update them later.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Date of birth

    private var dobRow: some View {
        Button { showDatePicker = true } label: {
            HStack {
                Text("Date of Birth").foregroundColor(.primary)
                Spacer()
                Text(dobLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Blood type

    private var bloodTypeRow: some View {
        HStack {
            Text("Blood Type").foregroundColor(.primary)
            Spacer()
            Picker("", selection: $bloodType) {
                Text("—").tag("")
                ForEach(bloodTypeOptions, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Generic text field

    @ViewBuilder
    private func fieldSection(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(mode == .edit ? .teal : .secondary)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(2...3)
                .padding(14)
                .background(Color.white)
                .cornerRadius(12)
        }
    }

    // MARK: - Insurance group

    private var insuranceGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insurance Information")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(mode == .edit ? .teal : .secondary)
            VStack(spacing: 0) {
                TextField("Insurance Provider", text: $insuranceProvider)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                Divider().padding(.leading, 14)
                TextField("Policy Number", text: $policyNumber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                Divider().padding(.leading, 14)
                TextField("Additional Insurance Information", text: $additionalInsuranceInfo)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Date picker sheet

    private var dobPickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Date of Birth").font(.headline)
                Spacer()
                Button("Done") { hasDOB = true; showDatePicker = false }
                    .fontWeight(.semibold)
            }
            .padding()
            DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
        }
        .presentationDetents([.height(320)])
    }

    // MARK: - API: save

    private func saveAction() async {
        isSaving = true
        if let token = appState.token,
           let url = URL(string: "\(AppConfig.baseURL)/users/me/health-info") {
            var body: [String: Any] = [
                "bloodType": bloodType,
                "medicalConditions": medicalConditions,
                "allergies": allergies,
                "insuranceProvider": insuranceProvider,
                "policyNumber": policyNumber,
                "additionalInsuranceInfo": additionalInsuranceInfo,
                "medicalHistory": medicalHistory,
            ]
            if hasDOB {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withFullDate]
                body["dateOfBirth"] = f.string(from: dateOfBirth)
            }
            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: req)
        }
        await MainActor.run {
            isSaving = false
            if mode == .onboarding { navigateToMain = true }
            else { dismiss() }
        }
    }

    // MARK: - API: load

    private func loadHealthInfo() async {
        guard let token = appState.token,
              let url = URL(string: "\(AppConfig.baseURL)/users/me/health-info")
        else { return }
        await MainActor.run { isLoadingData = true }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { await MainActor.run { isLoadingData = false }; return }
        await MainActor.run {
            isLoadingData = false
            if let dob = json["date_of_birth"] as? String, !dob.isEmpty {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withFullDate]
                if let d = f.date(from: dob) { dateOfBirth = d; hasDOB = true }
            }
            bloodType = json["blood_type"] as? String ?? ""
            medicalConditions = json["medical_conditions"] as? String ?? ""
            allergies = json["allergies"] as? String ?? ""
            insuranceProvider = json["insurance_provider"] as? String ?? ""
            policyNumber = json["policy_number"] as? String ?? ""
            additionalInsuranceInfo = json["additional_insurance_info"] as? String ?? ""
            medicalHistory = json["medical_history"] as? String ?? ""
        }
    }
}

#Preview {
    HealthInfoView(mode: .onboarding)
        .environmentObject(AppState())
}
