//
//  SOSContactsView.swift
//  safeOne
//
//  Created by Ivan Yuantama Pradipta on 03/06/26.
//

// SOSContactsView.swift
import SwiftUI

struct SOSContact: Codable, Identifiable {
    let id: String
    let name: String
    let number: String
    let icon: String
}

struct SOSContactsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var contacts: [SOSContact] = []

    var body: some View {
        NavigationStack {
            List(contacts) { contact in
                Button {
                    if let url = URL(string: "tel://\(contact.number)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: contact.icon)
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red)
                            .clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text(contact.name).font(.headline)
                            Text(contact.number).font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "phone.fill").foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Contact Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                Task { await loadContacts() }
            }
        }
    }

    private func loadContacts() async {
        guard let url = URL(string: "\(AppConfig.baseURL)/calls/sos-contacts") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        if let decoded = try? JSONDecoder().decode([SOSContact].self, from: data) {
            await MainActor.run { self.contacts = decoded }
        }
    }
}
