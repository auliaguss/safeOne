//
//  AddReminderView.swift
//  safeOne
//

import SwiftUI
import PhotosUI

struct AddReminderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var initialElderId: String? = nil
    var editingReminder: APIReminder? = nil
    var onSaved: (() -> Void)? = nil

    @State private var selectedElderId: String?
    @State private var elders: [ElderItem] = []
    @State private var isLoadingElders = false

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedTime: Date = Date()
    // 0=Sun 1=Mon 2=Tue 3=Wed 4=Thu 5=Fri 6=Sat — default all selected (like iOS alarm)
    @State private var selectedDays: Set<Int> = Set(0...6)
    @State private var earlyReminder: EarlyReminderOption = .none
    @State private var category: ReminderCategory = .none
    @State private var selectedEmoji: String = "💊"
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var usePhoto = false

    let emojiOptions: [String] = ["💊", "🩺", "🏃", "🍎", "💉", "🩹", "🧘", "🚶"]

    private var isEditing: Bool { editingReminder != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // --- Elder Picker Pills ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assign to Elder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 16)

                        if isLoadingElders {
                            ProgressView()
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                        } else if elders.isEmpty {
                            Text("No elders connected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(elders) { elder in
                                        Button {
                                            selectedElderId = elder.id
                                        } label: {
                                            HStack(spacing: 6) {
                                                if let avatar = elder.avatar, !avatar.isEmpty {
                                                    Text(avatar).font(.caption)
                                                }
                                                Text(elder.name)
                                                    .font(.subheadline)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(selectedElderId == elder.id ? Color.blue : Color(.systemGray5))
                                            .foregroundColor(selectedElderId == elder.id ? .white : .primary)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 12)

                    Divider()

                    // --- Photo / Emoji Picker ---
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

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
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

                    // Repeat — alarm-style day picker
                    HStack {
                        Text("Repeat")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(repeatLabel)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { dow in
                            Spacer(minLength: 2)
                            Button {
                                if selectedDays.contains(dow) {
                                    selectedDays.remove(dow)
                                } else {
                                    selectedDays.insert(dow)
                                }
                            } label: {
                                Text(["S","M","T","W","T","F","S"][dow])
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(selectedDays.contains(dow) ? .white : .primary)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        Circle()
                                            .fill(selectedDays.contains(dow) ? Color.blue : Color(.systemGray5))
                                    )
                            }
                            Spacer(minLength: 2)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 14)

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
                    Text(isEditing ? "Edit Reminder" : "Add Reminder").font(.headline)
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
            .task {
                prefillFields()
                await fetchElders()
            }
        }
    }

    // MARK: - Repeat helpers

    private var repeatLabel: String {
        if selectedDays.isEmpty   { return "Never" }
        if selectedDays.count == 7 { return "Every day" }
        let names = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        return selectedDays.sorted().map { names[$0] }.joined(separator: ", ")
    }

    private var repeatOptionValue: String {
        if selectedDays.isEmpty   { return "none" }
        if selectedDays.count == 7 { return "everyday" }
        return "days:" + selectedDays.sorted().map(String.init).joined(separator: ",")
    }

    // Convert a stored repeat_option string back to a Set<Int> of DOW values (0=Sun…6=Sat)
    private static func parseDays(_ repeatOption: String, date: Date?) -> Set<Int> {
        switch repeatOption.lowercased() {
        case "none":     return Set()
        case "everyday": return Set(0...6)
        case "weekly":
            if let d = date {
                // Calendar.weekday is 1-based Sun=1 → convert to 0-based
                let wd = Calendar(identifier: .gregorian).component(.weekday, from: d) - 1
                return Set([wd])
            }
            return Set(0...6)
        case "monthly":
            return Set(0...6)
        default:
            if repeatOption.hasPrefix("days:") {
                let nums = repeatOption.dropFirst(5).split(separator: ",").compactMap { Int($0) }
                return Set(nums.filter { (0...6).contains($0) })
            }
            return Set(0...6)
        }
    }

    // Handles both "2026-06-05T09:00:00Z" and "2026-06-05T09:00:00.000Z" from PostgreSQL
    private static func parseDate(_ string: String) -> Date? {
        let withMs = ISO8601DateFormatter()
        withMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withMs.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    // MARK: - Prefill for Edit Mode
    private func prefillFields() {
        guard let r = editingReminder else {
            selectedElderId = initialElderId
            return
        }
        title = r.title
        notes = r.notes ?? ""
        selectedEmoji = r.imageName ?? "💊"
        selectedElderId = r.elderId ?? initialElderId

        if let d = Self.parseDate(r.date) {
            selectedDate = d
            selectedTime = d
        }

        selectedDays = Self.parseDays(r.repeatOption, date: Self.parseDate(r.date))

        if let ea = r.earlyReminder {
            earlyReminder = EarlyReminderOption.allCases.first {
                $0.rawValue.lowercased() == ea.lowercased()
            } ?? .none
        }

        if let cat = r.category {
            category = ReminderCategory.allCases.first {
                $0.rawValue.lowercased() == cat.lowercased()
            } ?? .none
        }
    }

    // MARK: - Fetch Elders
    private func fetchElders() async {
        guard let token = appState.token else { return }
        isLoadingElders = true
        do {
            let decoded = try await ReminderRepository.fetchElders(token: token)
            await MainActor.run {
                elders = decoded
                if selectedElderId == nil {
                    selectedElderId = initialElderId ?? decoded.first?.id
                }
                isLoadingElders = false
            }
        } catch {
            await MainActor.run { isLoadingElders = false }
        }
    }

    // MARK: - Save (Create or Update)
    private func saveReminder() async {
        guard let token = appState.token else {
            errorMessage = "Sesi tidak valid, silakan login ulang."
            return
        }
        guard let targetElderId = selectedElderId else {
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

        let body: [String: Any] = [
            "elderId": targetElderId,
            "title": title,
            "notes": notes,
            "date": ISO8601DateFormatter().string(from: finalDate),
            "repeatOption": repeatOptionValue,
            "earlyReminder": earlyReminder.rawValue,
            "category": category.rawValue.lowercased(),
            "totalCount": 1,
            "imageName": usePhoto ? "🖼️" : selectedEmoji
        ]

        do {
            if let r = editingReminder {
                _ = try await ReminderRepository.updateReminder(id: r.id, body, token: token)
            } else {
                _ = try await ReminderRepository.createReminder(body, token: token)
            }
            await MainActor.run {
                isSaving = false
                onSaved?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = "Gagal: \(error.localizedDescription)"
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
