//
//  AddReminderView.swift
//  safeOne
//

import SwiftUI
import PhotosUI

struct AddReminderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var elderId: String?
    var onSaved: (() -> Void)? = nil

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedTime: Date = Date()
    @State private var repeatOption: RepeatOption = .none
    @State private var earlyReminder: EarlyReminderOption = .none
    @State private var category: ReminderCategory = .none
    @State private var selectedEmoji: String = "💊"
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    // Photo picker
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var usePhoto = false

    let emojiOptions: [String] = ["💊", "🩺", "🏃", "🍎", "💉", "🩹", "🧘", "🚶"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // Photo / Emoji Picker
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 90, height: 90)

                            if let img = selectedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                            } else {
                                Text(selectedEmoji)
                                    .font(.system(size: 40))
                            }
                        }

                        // Emoji row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // Tombol pilih dari galeri
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    ZStack {
                                        Circle()
                                            .fill(usePhoto ? Color.blue.opacity(0.15) : Color(.systemGray5))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "photo")
                                            .font(.body)
                                            .foregroundColor(usePhoto ? .blue : .secondary)
                                    }
                                }

                                ForEach(emojiOptions, id: \.self) { emoji in
                                    Button(action: {
                                        selectedEmoji = emoji
                                        selectedImage = nil
                                        usePhoto = false
                                    }) {
                                        Text(emoji)
                                            .font(.title2)
                                            .padding(8)
                                            .background(
                                                Circle().fill(!usePhoto && selectedEmoji == emoji
                                                    ? Color.blue.opacity(0.15)
                                                    : Color.clear)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        Text(usePhoto ? "Foto dari galeri" : "Pilih emoji atau foto")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .onChange(of: selectedPhoto) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let img = UIImage(data: data) {
                                await MainActor.run {
                                    selectedImage = img
                                    usePhoto = true
                                }
                            }
                        }
                    }

                    Divider()

                    TextField("Title", text: $title)
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                    Divider().padding(.leading)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                        .padding(.horizontal)
                        .padding(.vertical, 14)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    Divider().padding(.top, 8)

                    SectionHeader(title: "Date & Time")

                    Button(action: { showDatePicker.toggle() }) {
                        FormPickerRowDisplay(
                            label: "Date",
                            value: selectedDate.formatted(.dateTime.month(.abbreviated).day().year())
                        )
                    }
                    if showDatePicker {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                    }

                    Divider().padding(.leading)

                    Button(action: { showTimePicker.toggle() }) {
                        FormPickerRowDisplay(
                            label: "Time",
                            value: selectedTime.formatted(.dateTime.hour().minute())
                        )
                    }
                    if showTimePicker {
                        DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .padding(.horizontal)
                    }

                    Divider().padding(.top, 8)

                    SectionHeader(title: "Reminder")

                    Menu {
                        ForEach(RepeatOption.allCases, id: \.self) { option in
                            Button(option.rawValue) { repeatOption = option }
                        }
                    } label: {
                        FormPickerRowDisplay(label: "Repeat", value: repeatOption.rawValue)
                    }

                    Divider().padding(.leading)

                    Menu {
                        ForEach(EarlyReminderOption.allCases, id: \.self) { option in
                            Button(option.rawValue) { earlyReminder = option }
                        }
                    } label: {
                        FormPickerRowDisplay(label: "Early Reminder", value: earlyReminder.rawValue)
                    }

                    Divider().padding(.leading)

                    Menu {
                        ForEach(ReminderCategory.allCases, id: \.self) { option in
                            Button(option.rawValue) { category = option }
                        }
                    } label: {
                        FormPickerRowDisplay(label: "Category", value: category.rawValue)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Add Reminder").font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await saveReminder() } }) {
                        ZStack {
                            Circle()
                                .fill(title.isEmpty || isSaving ? Color(.systemGray4) : Color.blue)
                                .frame(width: 32, height: 32)
                            if isSaving {
                                ProgressView().tint(.white).scaleEffect(0.7)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveReminder() async {
        guard let token = appState.token,
              let targetElderId = elderId,
              let url = URL(string: "https://safe-one-backend.vercel.app/api/reminders")
        else {
            errorMessage = "Pilih elder terlebih dahulu"
            return
        }

        isSaving = true
        errorMessage = nil

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComps = cal.dateComponents([.hour, .minute], from: selectedTime)
        comps.hour = timeComps.hour
        comps.minute = timeComps.minute
        let finalDate = cal.date(from: comps) ?? selectedDate

        // Kalau pakai foto, encode ke base64 dan simpan sebagai imageName
        // Backend saat ini menerima imageName sebagai string — tetap kirim emoji
        // Foto hanya ditampilkan lokal (backend belum support upload gambar)
        let imageNameToSend = usePhoto ? "🖼️" : selectedEmoji

        let body: [String: Any] = [
            "elderId": targetElderId,
            "title": title,
            "notes": notes,
            "date": ISO8601DateFormatter().string(from: finalDate),
            "repeatOption": repeatOption.rawValue.lowercased(),
            "earlyReminder": earlyReminder.rawValue,
            "category": category.rawValue.lowercased(),
            "totalCount": 1,
            "imageName": imageNameToSend
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse {
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            print("📡 Status: \(http.statusCode)")
            print("📦 Response: \(raw)")
            
            if http.statusCode == 201 {
                await MainActor.run {
                    isSaving = false
                    onSaved?()
                    dismiss()
                }
            } else {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Gagal (\(http.statusCode)): \(raw)"
                }
            }
        } else {
            await MainActor.run {
                isSaving = false
                errorMessage = "Network error"
            }
        }
    }
}

// MARK: - FormPickerRowDisplay
struct FormPickerRowDisplay: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}
