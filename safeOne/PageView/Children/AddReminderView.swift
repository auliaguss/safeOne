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
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var times: [Date] = [Date()]
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var earlyReminder: EarlyReminderOption = .none
    @State private var category: ReminderCategory = .none
    @State private var selectedEmoji: String = "💊"
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

                    // Start Date
                    Button(action: {
                        showStartDatePicker.toggle()
                        showEndDatePicker = false
                    }) {
                        FormPickerRowDisplay(
                            label: "Start Date",
                            value: startDate.formatted(.dateTime.month(.wide).day().year())
                        )
                    }
                    if showStartDatePicker {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                    }

                    Divider().padding(.leading)

                    // End Date (optional)
                    Button(action: {
                        showEndDatePicker.toggle()
                        showStartDatePicker = false
                    }) {
                        FormPickerRowDisplay(
                            label: "End Date",
                            value: hasEndDate
                                ? endDate.formatted(.dateTime.month(.wide).day().year())
                                : "None"
                        )
                    }
                    if showEndDatePicker {
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                            .onChange(of: endDate) { _, _ in hasEndDate = true }
                        if hasEndDate {
                            Button("Remove end date") {
                                hasEndDate = false
                                showEndDatePicker = false
                            }
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .padding(.vertical, 8)
                        }
                    }

                    Divider().padding(.top, 8)

                    // Times array
                    HStack {
                        Text("Time").foregroundColor(.primary)
                        Spacer()
                        Button("Add Time") {
                            times.append(times.last ?? Date())
                        }
                        .foregroundColor(.blue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 14)

                    ForEach(times.indices, id: \.self) { i in
                        Divider().padding(.leading)
                        HStack(spacing: 10) {
                            Button {
                                if times.count > 1 { times.remove(at: i) }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(times.count > 1 ? .red : Color(.systemGray4))
                                    .font(.title3)
                            }
                            .disabled(times.count == 1)

                            Text(ordinalLabel(i + 1))
                                .foregroundColor(.red)
                                .fontWeight(.medium)

                            Spacer()

                            DatePicker("", selection: $times[i], displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }

                    Divider().padding(.top, 8)

                    SectionHeader(title: "Reminder")

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

    // MARK: - Helpers

    private func ordinalLabel(_ n: Int) -> String {
        let suffix: String
        if (11...13).contains(n % 100) { suffix = "th" }
        else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    // Handles "2026-06-05T09:00:00Z" and "2026-06-05T09:00:00.000Z"
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

        // Start date
        if let d = Self.parseDate(r.date) { startDate = d }

        // End date
        if let edStr = r.endDate, !edStr.isEmpty,
           let ed = APIReminder.parseEndDate(edStr) {
            endDate = ed
            hasEndDate = true
        }

        // Times array
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        if let t = r.times, !t.isEmpty {
            let parsed = t.compactMap { timeFmt.date(from: $0) }
            times = parsed.isEmpty ? [Date()] : parsed
        } else if let d = Self.parseDate(r.date) {
            times = [d]
        }

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

        // Build the start date timestamp using startDate + first time
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: startDate)
        let firstTimeComps = cal.dateComponents([.hour, .minute], from: times.first ?? Date())
        comps.hour = firstTimeComps.hour
        comps.minute = firstTimeComps.minute
        let finalDate = cal.date(from: comps) ?? startDate

        // Times as ["HH:mm"] strings
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let timesArray = times.map { timeFmt.string(from: $0) }

        // End date as "yyyy-MM-dd" or NSNull
        let endDateValue: Any
        if hasEndDate {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            endDateValue = df.string(from: endDate)
        } else {
            endDateValue = NSNull()
        }

        let body: [String: Any] = [
            "elderId": targetElderId,
            "title": title,
            "notes": notes,
            "date": ISO8601DateFormatter().string(from: finalDate),
            "endDate": endDateValue,
            "times": timesArray,
            "earlyReminder": earlyReminder.rawValue,
            "category": category.rawValue.lowercased(),
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
