import SwiftUI
import UIKit

struct AddReminderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let reminder: Reminder?

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var repeatOption: RepeatOption = .none
    @State private var earlyReminder: EarlyReminderOption = .none
    @State private var category: ReminderCategory = .none
    @State private var selectedEmoji = "💊"
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showImageSourcePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showImagePicker = false

    private let emojiOptions = ["💊", "🩺", "🏃", "🍎", "💉", "🩹", "🧘", "🚶"]

    init(reminder: Reminder? = nil) {
        self.reminder = reminder
        _title = State(initialValue: reminder?.title ?? "")
        _notes = State(initialValue: reminder?.notes ?? "")
        _selectedDate = State(initialValue: reminder?.date ?? Date())
        _selectedTime = State(initialValue: reminder?.date ?? Date())
        _repeatOption = State(initialValue: reminder?.repeatOption ?? .none)
        _earlyReminder = State(initialValue: reminder?.earlyReminder ?? .none)
        _category = State(initialValue: reminder?.category ?? .none)
        _selectedEmoji = State(initialValue: reminder?.imageName ?? "💊")
    }
 
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        Button {
                            showImageSourcePicker = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 96, height: 96)

                                if let fileName = ReminderImageReference.fileName(from: selectedEmoji),
                                   let image = LocalImageStore.load(fileName: fileName) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 96)
                                        .clipShape(Circle())
                                } else {
                                    Text(selectedEmoji)
                                        .font(.system(size: 40))
                                }

                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .offset(x: 34, y: 34)
                            }
                        }
                        .buttonStyle(.plain)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(emojiOptions.indices, id: \.self) { i in
                                    let emoji = emojiOptions[i]
                                    Button(action: { selectedEmoji = emoji }) {
                                        Text(emoji)
                                            .font(.title2)
                                            .padding(8)
                                            .background(
                                                Circle()
                                                    .fill(selectedEmoji == emoji
                                                          ? Color.blue.opacity(0.15)
                                                          : Color.clear)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        Text("Tap image to add photo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider()

                    TextField("Title", text: $title)
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                    Divider().padding(.leading)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                        .padding(.horizontal)
                        .padding(.vertical, 14)

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
            .confirmationDialog("Reminder Photo", isPresented: $showImageSourcePicker) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Camera") {
                        imageSourceType = .camera
                        showImagePicker = true
                    }
                }

                Button("Gallery") {
                    imageSourceType = .photoLibrary
                    showImagePicker = true
                }

                Button("Remove Photo", role: .destructive) {
                    selectedEmoji = "💊"
                }

                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: imageSourceType) { image in
                    if let fileName = LocalImageStore.save(image) {
                        selectedEmoji = ReminderImageReference.imageName(for: fileName)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(reminder == nil ? "Add Reminder" : "Edit Reminder")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await saveReminder()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(title.isEmpty ? Color(.systemGray4) : Color.blue)
                                .frame(width: 32, height: 32)
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveReminder() async {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComps = cal.dateComponents([.hour, .minute], from: selectedTime)
        comps.hour = timeComps.hour
        comps.minute = timeComps.minute
        let finalDate = cal.date(from: comps) ?? selectedDate

        let newReminder = Reminder(
            id: reminder?.id ?? UUID(),
            title: title,
            notes: notes,
            date: finalDate,
            repeatOption: repeatOption,
            earlyReminder: earlyReminder,
            category: category,
            isCompleted: reminder?.isCompleted ?? false,
            completedCount: reminder?.completedCount ?? 0,
            totalCount: reminder?.totalCount ?? 1,
            elderID: reminder?.elderID ?? appState.selectedElder?.id ?? UUID(),
            isPast: reminder?.isPast ?? false,
            imageName: selectedEmoji
        )

        await appState.saveReminder(newReminder)

        dismiss()
    }
}

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

#Preview {
    AddReminderView()
        .environmentObject(AppState())
}
