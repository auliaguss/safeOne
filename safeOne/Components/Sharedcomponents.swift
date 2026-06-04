import SwiftUI

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
        .onChange(of: appState.elders.count) {
            if appState.selectedElderIndex >= appState.elders.count {
                appState.selectedElderIndex = max(0, appState.elders.count - 1)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String

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

struct FormRowDisplay: View {
    let label: String
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
