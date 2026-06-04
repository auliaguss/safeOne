import SwiftUI

struct EmergencyContactsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showEditor = false
    @State private var editingContact: EmergencyContact?

    var body: some View {
        List {
            if appState.emergencyContacts.isEmpty {
                Text("No emergency contacts yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(appState.emergencyContacts) { contact in
                    Button {
                        editingContact = contact
                        showEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconName(for: contact.category))
                                .foregroundColor(.blue)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(contact.name)
                                        .font(.body)
                                    if contact.isPrimary {
                                        Text("Primary")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(contact.phoneNumber)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(contact.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.compactMap { index in
                        appState.emergencyContacts.indices.contains(index) ? appState.emergencyContacts[index].id : nil
                    }
                    appState.deleteEmergencyContacts(ids: ids)
                }
            }
        }
        .navigationTitle("Emergency Services")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingContact = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            EmergencyContactEditorView(contact: editingContact)
                .environmentObject(appState)
        }
    }

    private func iconName(for category: EmergencyContactCategory) -> String {
        switch category {
        case .caregiver:
            return "person.2.fill"
        case .ambulance:
            return "cross.case.fill"
        case .hospital:
            return "building.2.fill"
        case .police:
            return "shield.lefthalf.filled"
        case .firefighters:
            return "flame.fill"
        case .family:
            return "house.fill"
        case .other:
            return "phone.fill"
        }
    }
}

struct EmergencyContactEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let contact: EmergencyContact?
    @State private var name: String
    @State private var phoneNumber: String
    @State private var category: EmergencyContactCategory
    @State private var isPrimary: Bool

    init(contact: EmergencyContact? = nil) {
        self.contact = contact
        _name = State(initialValue: contact?.name ?? "")
        _phoneNumber = State(initialValue: contact?.phoneNumber ?? "")
        _category = State(initialValue: contact?.category ?? .caregiver)
        _isPrimary = State(initialValue: contact?.isPrimary ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $name)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Type") {
                    Picker("Category", selection: $category) {
                        ForEach(EmergencyContactCategory.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    Toggle("Primary Contact", isOn: $isPrimary)
                }
            }
            .navigationTitle(contact == nil ? "Add Contact" : "Edit Contact")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let updated = EmergencyContact(
                            id: contact?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            isPrimary: isPrimary
                        )

                        if let contact {
                            appState.updateEmergencyContact(updated)
                        } else {
                            appState.addEmergencyContact(updated)
                        }

                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

