//
//  PaywallView.swift
//  safeOne
//

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscription = SubscriptionManager.shared

    @State private var selectedPlan: PremiumPlan = .yearly
    @State private var showPurchaseUnavailable = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppSurfaceBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, 44)

                    sectionTitle(appState.text("Yang Kamu Dapatkan", "What’s Included"))
                        .padding(.top, 24)

                    featureCard
                        .padding(.top, 12)
                        .padding(.horizontal, -8)

                    sectionTitle(appState.text("Pilih paketmu", "Choose your plan"))
                        .padding(.top, 28)

                    HStack(spacing: 16) {
                        ForEach(PremiumPlan.allCases) { plan in
                            PlanCard(plan: plan, isSelected: selectedPlan == plan)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) { selectedPlan = plan }
                                }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { footer }

            closeButton
                .padding(.trailing, 20)
                .padding(.top, 8)
        }
        // Purchases aren't wired yet — the CTA offers the redeem code instead.
        .redeemCodeAlert(
            isPresented: $showPurchaseUnavailable,
            title: appState.text("Pembelian segera hadir", "Purchases coming soon"),
            message: appState.text(
                "Pembelian dalam aplikasi belum tersedia. Punya kode redeem? Masukkan di bawah.",
                "In-app purchases aren't available yet. Have a redeem code? Enter it below."
            ),
            onRedeemed: { dismiss() }
        )
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appState.text("Buka fitur ini\ndengan Premium", "Unlock this feature\nwith Premium"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
            Text(appState.text(
                "Upgrade untuk mengelola perawatan harian dengan lebih mudah dan dapat bantuan saat keluargamu membutuhkannya.",
                "Upgrade to manage daily care more easily and get help when your family needs it."
            ))
            .font(.system(size: 15))
            .foregroundColor(Color(hex: "6C6C70"))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundColor(Color(hex: "8E8E93"))
    }

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaywallFeatureRow(
                icon: "call",
                title: appState.text("Panggilan Darurat", "Emergency Call"),
                subtitle: appState.text("Hubungi pendamping dengan cepat saat butuh bantuan.", "Quickly contact a caregiver when help is needed.")
            )
            PaywallFeatureRow(
                icon: "clock",
                title: appState.text("Pengingat tanpa batas", "Unlimited reminders"),
                subtitle: appState.text("Buat pengingat sebanyak yang kamu butuhkan.", "Create as many reminders as you need.")
            )
            PaywallFeatureRow(
                icon: "multipleElder",
                title: appState.text("Rawat beberapa lansia", "Care for multiple elders"),
                subtitle: appState.text("Kelola perawatan untuk beberapa anggota keluarga.", "Manage care for multiple family members.")
            )
            PaywallFeatureRow(
                icon: "multipleFamily",
                title: appState.text("Tetap terhubung sebagai keluarga", "Stay connected as a family"),
                subtitle: appState.text(
                    "Hubungkan hingga \(AppConfig.premiumCaregiverLimit) pendamping.",
                    "Connect up to \(AppConfig.premiumCaregiverLimit) caregivers."
                )
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white, lineWidth: 1.5)
        )
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                showPurchaseUnavailable = true
            } label: {
                Text(appState.text("Buka dengan Premium", "Unlock with Premium"))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(Color.black))
            }
            .padding(.horizontal, 16)

            Text(appState.text(
                "Langganan diperpanjang otomatis. Batalkan kapan saja.",
                "Subscription renews automatically. Cancel anytime."
            ))
            .font(.system(size: 12))
            .foregroundColor(Color(hex: "8E8E93"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .accessibilityLabel(appState.text("Tutup", "Close"))
    }
}

// MARK: - Feature Row

private struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Asset already includes the tile background.
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.black)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    @EnvironmentObject var appState: AppState
    let plan: PremiumPlan
    let isSelected: Bool

    private var name: String {
        switch plan {
        case .monthly: return appState.text("Bulanan", "Monthly")
        case .yearly: return appState.text("Tahunan", "Yearly")
        }
    }

    private var period: String {
        switch plan {
        case .monthly: return appState.text("/ bulan", "/ month")
        case .yearly: return appState.text("/ tahun", "/ year")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .padding(.bottom, 4)

            if let fullPrice = plan.fullPrice {
                Text(PremiumPlan.rupiah(fullPrice))
                    .font(.system(size: 12))
                    .strikethrough()
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Text(PremiumPlan.rupiah(plan.price))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.black)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(period)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "3A3A3C"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.black : Color(hex: "D1D1D6"), lineWidth: isSelected ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if let savings = plan.savings {
                Text(appState.text("HEMAT \(PremiumPlan.rupiah(savings))", "SAVE \(PremiumPlan.rupiah(savings))"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: "3D8EF0")))
                    .offset(x: -12, y: -12)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Redeem Code Alert

private struct RedeemCodeAlert: ViewModifier {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    let title: String
    let message: String
    var onRedeemed: () -> Void

    @State private var code = ""
    @State private var errorMessage: String? = nil
    @State private var showSuccess = false

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                TextField(appState.text("Kode redeem", "Redeem code"), text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button(appState.text("Redeem", "Redeem")) { redeem() }
                Button(appState.text("Batal", "Cancel"), role: .cancel) {
                    code = ""
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? message)
            }
            .alert(appState.text("Premium aktif", "Premium unlocked"), isPresented: $showSuccess) {
                Button(appState.text("Mantap", "Great"), role: .cancel) { onRedeemed() }
            } message: {
                Text(appState.text("Semua fitur Premium sekarang tersedia di akun ini.", "All Premium features are now available on this account."))
            }
    }

    private func redeem() {
        let success = SubscriptionManager.shared.redeem(code)
        code = ""
        if success {
            errorMessage = nil
            showSuccess = true
        } else {
            errorMessage = appState.text("Kode tidak valid. Coba lagi.", "Invalid code. Please try again.")
            // Re-present after the current alert finishes dismissing.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isPresented = true }
        }
    }
}

extension View {
    func redeemCodeAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        onRedeemed: @escaping () -> Void = {}
    ) -> some View {
        modifier(RedeemCodeAlert(isPresented: isPresented, title: title, message: message, onRedeemed: onRedeemed))
    }
}

// MARK: - Premium Profile Section

/// Premium status + upgrade/redeem entry points, shared by both profile screens.
struct PremiumSection: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var showRedeem = false

    var body: some View {
        Section {
            HStack {
                Label(appState.text("Status", "Status"), systemImage: "crown")
                Spacer()
                Text(subscription.isSubscribed ? "Premium" : appState.text("Gratis", "Free"))
                    .fontWeight(.semibold)
                    .foregroundStyle(subscription.isSubscribed ? Color.blue : Color.secondary)
            }
            .accessibilityElement(children: .combine)
            .redeemCodeAlert(
                isPresented: $showRedeem,
                title: appState.text("Redeem Kode", "Redeem Code"),
                message: appState.text("Masukkan kode untuk membuka Premium.", "Enter your code to unlock Premium.")
            )
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(appState)
            }

            if !subscription.isSubscribed {
                Button {
                    showPaywall = true
                } label: {
                    Label(appState.text("Upgrade ke Premium", "Upgrade to Premium"), systemImage: "sparkles")
                }
                Button {
                    showRedeem = true
                } label: {
                    Label(appState.text("Redeem Kode", "Redeem Code"), systemImage: "ticket")
                }
            }
        } header: {
            Text("Premium")
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(AppState())
}
