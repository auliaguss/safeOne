//
//  Sharedcomponents.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import SwiftUI

struct AppSurfaceBackground: View {
    var body: some View {
        ZStack {
            Color.white
            RadialGradient(
                colors: [Color(red: 0, green: 218/255, blue: 195/255).opacity(0.15), Color.clear],
                center: UnitPoint(x: 0.2, y: 0.1),
                startRadius: 0,
                endRadius: 400
            )
            RadialGradient(
                colors: [Color(red: 0, green: 145/255, blue: 1.0).opacity(0.20), Color.clear],
                center: UnitPoint(x: 0.8, y: 0.8),
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
}

struct ProfileDestinationContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .scrollContentBackground(.hidden)
            .background(AppSurfaceBackground())
    }
}

struct ConnectedPersonRow: View {
    let name: String
    let subtitle: String
    let avatar: String?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                if let avatar, !avatar.isEmpty {
                    Text(avatar)
                        .font(.title3)
                } else {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct ListStatusRow: View {
    let text: String
    var showsProgress = false

    var body: some View {
        HStack(spacing: 12) {
            if showsProgress {
                ProgressView()
            }
            Text(text)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Elder Selector

struct ElderSelectorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            ForEach(appState.elders.indices, id: \.self) { index in
                let elder = appState.elders[index]
                let isSelected = appState.selectedElderIndex == index

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.selectedElderIndex = index
                    }
                }) {
                    Text(elder.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.black : Color(.systemGray5))
                        )
                }
            }
            Spacer()
        }
        .onChange(of: appState.elders.count) { newCount in
            // Guard selectedElderIndex if elders shrink
            if appState.selectedElderIndex >= newCount {
                appState.selectedElderIndex = max(0, newCount - 1)
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 4)
            Spacer()
        }
    }
}

// MARK: - Form Row Display (read-only)

struct FormRowDisplay: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}
