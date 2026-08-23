//
//  DataPrivacyView.swift
//  safeOne
//

import SwiftUI

// MARK: - Data & Privacy View

struct DataPrivacyView: View {

    var body: some View {
        List {

            // Summary card
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your privacy matters")
                        .font(.headline)
                    Text("SafeOne collects only what's needed to keep elders safe and families connected. We never sell your data.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                PrivacyDisclosure(title: "What We Collect") {
                    PrivacyRow(label: "Personal info", detail: "Name, medical info (optional)")
                    PrivacyRow(label: "Reminders & schedules", detail: "Title, notes, times, dates")
                    PrivacyRow(label: "Audio / video", detail: "Call data — streamed only, not stored")
                    PrivacyRow(label: "Device info", detail: "For performance and debugging")
                }
            }

            Section {
                PrivacyDisclosure(title: "Why We Collect It") {
                    PrivacyRow(label: "Phone number", detail: "Connect you with family members")
                    PrivacyRow(label: "Reminders", detail: "Store schedules and send notifications")
                    PrivacyRow(label: "Camera & mic", detail: "Enable video and voice calls")
                    PrivacyRow(label: "Device info", detail: "Diagnose crashes and improve the app")
                }
            }

            Section {
                PrivacyDisclosure(title: "How Data Is Used") {
                    PrivacyBullet("Send reminders and notifications to elders")
                    PrivacyBullet("Connect family during calls and SOS events")
                    PrivacyBullet("Improve app performance and reliability")
                    PrivacyBullet("Personalize the experience for each user")
                }
            }

            Section {
                PrivacyDisclosure(title: "Data Sharing") {
                    PrivacyBullet("Shared with your connected family members — this is the core feature")
                    PrivacyBullet("Supabase: secure database hosting")
                    PrivacyBullet("Agora: real-time voice and video calls")
                    Text("We do not sell your data to anyone.")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.vertical, 2)
                }
            }

            Section {
                PrivacyDisclosure(title: "Storage & Security") {
                    PrivacyBullet("All data is transmitted over HTTPS (encrypted)")
                    PrivacyBullet("Authentication via secure tokens — passwords are never stored in plain text")
                    PrivacyBullet("Access control ensures only authorized users can view data")
                }
            }

            Section {
                PrivacyDisclosure(title: "Your Control") {
                    PrivacyRow(label: "Edit profile", detail: "Anytime from Profile tab")
                    PrivacyRow(label: "Manage elders", detail: "Add or remove connected elders")
                    PrivacyRow(label: "App permissions", detail: "Camera, mic & notifications via iOS Settings")
                    PrivacyRow(label: "Delete account", detail: "Contact support to remove all data")
                }
            }

            Section {
                PrivacyDisclosure(title: "Permissions") {
                    PrivacyRow(label: "Camera", detail: "Video calls between family members")
                    PrivacyRow(label: "Microphone", detail: "Voice and video calls")
                    PrivacyRow(label: "Notifications", detail: "Reminder alerts and missed activity")
                }
            }

            Section {
                PrivacyDisclosure(title: "Data Retention") {
                    PrivacyBullet("Data is stored while your account is active")
                    PrivacyBullet("Deleted within 30 days after account deletion")
                    PrivacyBullet("Call streams are not recorded or retained")
                }
            }

            Section {
                PrivacyDisclosure(title: "Policy Updates") {
                    PrivacyBullet("We may update this policy as the app evolves")
                    PrivacyBullet("You will be notified of any significant changes")
                    PrivacyBullet("Continued use of the app means you accept the updated policy")
                }
            }

            Section {
                Text("Last updated: June 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Reusable subviews

private struct PrivacyDisclosure<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        } label: {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
                .padding(.vertical, 2)
        }
    }
}

private struct PrivacyRow: View {
    let label: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 140, alignment: .leading)
            Text(detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PrivacyBullet: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.secondary)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        DataPrivacyView()
    }
}
