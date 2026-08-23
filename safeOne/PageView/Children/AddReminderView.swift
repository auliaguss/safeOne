//
//  AddReminderView.swift
//  safeOne
//

import SwiftUI
import PhotosUI

private struct TimeEntry: Identifiable {
    let id: UUID
    var date: Date
    init(date: Date) { self.id = UUID(); self.date = date }
}

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
    @State private var times: [TimeEntry] = [TimeEntry(date: Date())]
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var earlyReminder: EarlyReminderOption = .none
    @State private var category: ReminderCategory = .none
    @State private var selectedEmoji: String = "💊"
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteAlert = false
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

                        Text(appState.text(
                            usePhoto ? "Foto dari galeri" : "Pilih emoji atau foto",
                            usePhoto ? "Photo from gallery" : "Choose emoji or photo"
                        ))
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

                    // Title + Notes Card
                    VStack(spacing: 0) {
                        TextField("Title", text: $title)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        Divider().padding(.leading, 16)
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: false)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal, 16)
                    }

                    // Date & Time
                    Text("Date & Time")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 0) {
                        Button(action: {
                            showStartDatePicker.toggle()
                            showEndDatePicker = false
                        }) {
                            HStack {
                                Text("Start Date")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(startDate.formatted(.dateTime.day().month(.wide).year()))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(20)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        if showStartDatePicker {
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .padding(.horizontal)
                        }

                        Divider().padding(.leading, 16)

                        Button(action: {
                            showEndDatePicker.toggle()
                            showStartDatePicker = false
                        }) {
                            HStack {
                                Text("End Date")
                                    .foregroundColor(.primary)
                                Spacer()
                                Group {
                                    if hasEndDate {
                                        Text(endDate.formatted(.dateTime.day().month(.wide).year()))
                                    } else {
                                        Text("None")
                                    }
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5))
                                .cornerRadius(20)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
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
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)

                    // Time Card
                    VStack(spacing: 0) {
                        HStack {
                            Text("Time").foregroundColor(.primary)
                            Spacer()
                            Button("Add Time") {
                                times.append(TimeEntry(date: times.last?.date ?? Date()))
                            }
                            .foregroundColor(.blue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        ForEach($times) { $entry in
                            Divider().padding(.leading, 16)
                            HStack(spacing: 10) {
                                Button {
                                    if times.count > 1 { times.removeAll { $0.id == entry.id } }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(times.count > 1 ? .red : Color(.systemGray4))
                                        .font(.title3)
                                }
                                .disabled(times.count == 1)

                                Text(ordinalLabel((times.firstIndex(where: { $0.id == entry.id }) ?? 0) + 1))
                                    .foregroundColor(.red)
                                    .fontWeight(.medium)

                                Spacer()

                                DatePicker("", selection: $entry.date, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    if isEditing {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                if isDeleting {
                                    ProgressView().tint(.red)
                                } else {
                                    Text("Delete Reminder").fontWeight(.medium)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 14)
                        }
                        .foregroundColor(.red)
                        .disabled(isDeleting)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete Reminder", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { Task { await deleteReminder() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(appState.text("Yakin ingin menghapus \"\(editingReminder?.title ?? "pengingat ini")\"?", "Are you sure you want to delete \"\(editingReminder?.title ?? "this reminder")\"?"))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(appState.text(isEditing ? "Ubah Pengingat" : "Tambah Pengingat", isEditing ? "Edit Reminder" : "Add Reminder")).font(.headline)
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

    private func encodePhoto() -> String {
        guard let img = selectedImage else { return "🖼️" }
        let side: CGFloat = 300
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let resized = renderer.image { _ in
            img.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        guard let data = resized.jpegData(compressionQuality: 0.7) else { return "🖼️" }
        return "data:image/jpeg;base64," + data.base64EncodedString()
    }

    private func ordinalLabel(_ n: Int) -> String {
        if appState.language == .indonesian { return "\(n)" }
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
        selectedElderId = r.elderId ?? initialElderId

        // Decode stored image back to preview
        if let name = r.imageName, name.hasPrefix("data:"),
           let comma = name.firstIndex(of: ","),
           let data = Data(base64Encoded: String(name[name.index(after: comma)...])),
           let img = UIImage(data: data) {
            selectedImage = img
            usePhoto = true
            selectedEmoji = "💊"
        } else {
            selectedEmoji = r.imageName ?? "💊"
            selectedImage = nil
            usePhoto = false
        }

        // Start date
        if let d = Self.parseDate(r.date) { startDate = d }

        // End date
        if let edStr = r.endDate, !edStr.isEmpty,
           let ed = APIReminder.parseEndDate(edStr) {
            endDate = ed
            hasEndDate = true
        }

        // Times array — stored as UTC "HH:mm"; parse as UTC so DatePicker shows local time
        let timeFmt = DateFormatter()
        timeFmt.timeZone = TimeZone(abbreviation: "UTC")
        timeFmt.dateFormat = "HH:mm"
        if let t = r.times, !t.isEmpty {
            let parsed = t.compactMap { timeFmt.date(from: $0) }.map { TimeEntry(date: $0) }
            times = parsed.isEmpty ? [TimeEntry(date: Date())] : parsed
        } else if let d = Self.parseDate(r.date) {
            times = [TimeEntry(date: d)]
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

    // MARK: - Delete
    private func deleteReminder() async {
        guard let token = appState.token, let reminder = editingReminder else { return }
        isDeleting = true
        do {
            try await ReminderRepository.deleteReminder(id: reminder.id, token: token)
            await MainActor.run {
                isDeleting = false
                onSaved?()
                dismiss()
            }
        } catch {
            await MainActor.run { isDeleting = false }
        }
    }

    // MARK: - Save (Create or Update)
    private func saveReminder() async {
        guard let token = appState.token else {
            errorMessage = appState.text("Sesi tidak valid, silakan login ulang.", "Your session is invalid. Please sign in again.")
            return
        }
        guard let targetElderId = selectedElderId else {
            errorMessage = appState.text("Pilih lansia terlebih dahulu", "Please select an elder first")
            return
        }

        isSaving = true
        errorMessage = nil

        // Build the start date timestamp using startDate + first time
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: startDate)
        let firstTimeComps = cal.dateComponents([.hour, .minute], from: times.first?.date ?? Date())
        comps.hour = firstTimeComps.hour
        comps.minute = firstTimeComps.minute
        let finalDate = cal.date(from: comps) ?? startDate

        // Times as UTC "HH:mm" strings so the server-side scheduler can compare directly
        let timeFmt = DateFormatter()
        timeFmt.timeZone = TimeZone(abbreviation: "UTC")
        timeFmt.dateFormat = "HH:mm"
        let timesArray = times.map { timeFmt.string(from: $0.date) }

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
            "imageName": usePhoto ? encodePhoto() : selectedEmoji
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
                errorMessage = appState.text("Gagal: \(error.localizedDescription)", "Failed: \(error.localizedDescription)")
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
