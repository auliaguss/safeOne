//
//  Sharedcomponents.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import SwiftUI

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
