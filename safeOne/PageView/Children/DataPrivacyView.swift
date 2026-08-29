//
//  DataPrivacyView.swift
//  safeOne
//

import SwiftUI

struct DataPrivacyView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.text("Privasi Anda penting", "Your privacy matters"))
                        .font(.headline)
                    Text(appState.text(
                        "SafeOne hanya mengumpulkan data yang diperlukan untuk menjaga lansia tetap aman dan keluarga tetap terhubung. Kami tidak pernah menjual data Anda.",
                        "SafeOne collects only the data needed to keep elders safe and families connected. We never sell your data."
                    ))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                PrivacyDisclosure(title: appState.text("Data yang Kami Kumpulkan", "What We Collect")) {
                    PrivacyRow(label: appState.text("Informasi pribadi", "Personal info"), detail: appState.text("Nama, informasi kesehatan (opsional)", "Name, medical info (optional)"))
                    PrivacyRow(label: appState.text("Pengingat & jadwal", "Reminders & schedules"), detail: appState.text("Judul, catatan, waktu, dan tanggal", "Title, notes, times, dates"))
                    PrivacyRow(label: appState.text("Audio / video", "Audio / video"), detail: appState.text("Data panggilan hanya diteruskan, tidak disimpan", "Call data is streamed only and not stored"))
                    PrivacyRow(label: appState.text("Info perangkat", "Device info"), detail: appState.text("Untuk performa dan debugging", "For performance and debugging"))
                }
            }

            Section {
                PrivacyDisclosure(title: appState.text("Mengapa Kami Mengumpulkannya", "Why We Collect It")) {
                    PrivacyRow(label: appState.text("Nomor telepon", "Phone number"), detail: appState.text("Menghubungkan Anda dengan anggota keluarga", "Connect you with family members"))
                    PrivacyRow(label: appState.text("Pengingat", "Reminders"), detail: appState.text("Menyimpan jadwal dan mengirim notifikasi", "Store schedules and send notifications"))
                    PrivacyRow(label: appState.text("Kamera & mikrofon", "Camera & mic"), detail: appState.text("Mengaktifkan panggilan video dan suara", "Enable video and voice calls"))
                    PrivacyRow(label: appState.text("Info perangkat", "Device info"), detail: appState.text("Mendiagnosis gangguan dan meningkatkan aplikasi", "Diagnose crashes and improve the app"))
                }
            }

            Section {
                PrivacyDisclosure(title: appState.text("Cara Data Digunakan", "How Data Is Used")) {
                    PrivacyBullet(appState.text("Mengirim pengingat dan notifikasi ke lansia", "Send reminders and notifications to elders"))
                    PrivacyBullet(appState.text("Menghubungkan keluarga saat panggilan dan keadaan darurat", "Connect family during calls and SOS events"))
                    PrivacyBullet(appState.text("Meningkatkan performa dan keandalan aplikasi", "Improve app performance and reliability"))
                    PrivacyBullet(appState.text("Menyesuaikan pengalaman untuk setiap pengguna", "Personalize the experience for each user"))
                }
            }

            Section {
                PrivacyDisclosure(title: appState.text("Berbagi Data", "Data Sharing")) {
                    PrivacyBullet(appState.text("Dibagikan kepada anggota keluarga yang terhubung karena ini fungsi utama aplikasi", "Shared with your connected family members because this is the app's core feature"))
                    PrivacyBullet("Supabase: secure database hosting")
                    PrivacyBullet("Agora: real-time voice and video calls")
                    Text(appState.text("Kami tidak menjual data Anda kepada siapa pun.", "We do not sell your data to anyone."))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.vertical, 2)
                }
            }

            Section {
                PrivacyDisclosure(title: appState.text("Penyimpanan & Keamanan", "Storage & Security")) {
                    PrivacyBullet(appState.text("Semua data dikirim melalui HTTPS dan terenkripsi", "All data is transmitted over HTTPS and encrypted"))
                    PrivacyBullet(appState.text("Autentikasi memakai token aman dan kata sandi tidak disimpan dalam bentuk teks biasa", "Authentication uses secure tokens and passwords are never stored in plain text"))
                    PrivacyBullet(appState.text("Kontrol akses memastikan hanya pengguna berwenang yang dapat melihat data", "Access control ensures only authorized users can view data"))
                }
            }

            Section {
                PrivacyDisclosure(title: appState.text("Kontrol Anda", "Your Control")) {
                    PrivacyRow(label: appState.text("Ubah profil", "Edit profile"), detail: appState.text("Kapan saja dari tab Profil", "Anytime from the Profile tab"))
                    PrivacyRow(label: appState.text("Kelola keluarga", "Manage family"), detail: appState.text("Tambah atau hapus anggota keluarga yang terhubung", "Add or remove connected family members"))
                    PrivacyRow(label: appState.text("Izin aplikasi", "App permissions"), detail: appState.text("Kamera, mikrofon, dan notifikasi lewat Pengaturan iOS", "Camera, mic, and notifications via iOS Settings"))
                    PrivacyRow(label: appState.text("Hapus akun", "Delete account"), detail: appState.text("Hubungi dukungan untuk menghapus seluruh data", "Contact support to remove all data"))
                }
            }

            Section {
                PrivacyDisclosure(title: appState.text("Izin", "Permissions")) {
                    PrivacyRow(label: appState.text("Kamera", "Camera"), detail: appState.text("Panggilan video antar anggota keluarga", "Video calls between family members"))
                    PrivacyRow(label: appState.text("Mikrofon", "Microphone"), detail: appState.text("Panggilan suara dan video", "Voice and video calls"))
                    PrivacyRow(label: appState.text("Notifikasi", "Notifications"), detail: appState.text("Pengingat dan aktivitas yang terlewat", "Reminder alerts and missed activity"))
                }
            }

            Section {
                PrivacyDisclosure(title: appState.text("Retensi Data", "Data Retention")) {
                    PrivacyBullet(appState.text("Data disimpan selama akun Anda aktif", "Data is stored while your account is active"))
                    PrivacyBullet(appState.text("Dihapus dalam 30 hari setelah akun dihapus", "Deleted within 30 days after account deletion"))
                    PrivacyBullet(appState.text("Streaming panggilan tidak direkam atau disimpan", "Call streams are not recorded or retained"))
                }
            }

            Section {
                PrivacyDisclosure(title: appState.text("Pembaruan Kebijakan", "Policy Updates")) {
                    PrivacyBullet(appState.text("Kebijakan ini dapat diperbarui seiring perkembangan aplikasi", "We may update this policy as the app evolves"))
                    PrivacyBullet(appState.text("Anda akan diberi tahu jika ada perubahan penting", "You will be notified of any significant changes"))
                    PrivacyBullet(appState.text("Dengan terus menggunakan aplikasi, Anda menyetujui kebijakan yang diperbarui", "Continued use of the app means you accept the updated policy"))
                }
            }

            Section {
                Text(appState.text("Terakhir diperbarui: Juni 2025", "Last updated: June 2025"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppSurfaceBackground())
        .navigationTitle(appState.text("Data & Privasi", "Data & Privacy"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyDisclosure<Content: View>: View {
    let title: String
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
    let label: String
    let detail: String

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
    let text: String

    init(_ text: String) {
        self.text = text
    }

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
            .environmentObject(AppState())
    }
}
