//
//  TutorialOverlayView.swift
//  safeOne
//

import SwiftUI

/// Full-screen coachmark overlay: dims the real app UI, cuts a see-through hole
/// around the current step's target, and shows an explanation card pointing at it.
/// Sits above the app content but blocks all touches except its own Next/Done
/// button — this is what guarantees the SOS step can never trigger a real call.
struct TutorialOverlayView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tutorialManager: TutorialManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isCardFocused: Bool

    @State private var measuredCardSize: CGSize = CGSize(width: 280, height: 170)

    private let spotlightPadding: CGFloat = 10
    private let cardMaxWidth: CGFloat = 320
    private let cardTargetSpacing: CGFloat = 18
    private let screenEdgeMargin: CGFloat = 24

    private enum Placement { case above, below, centered }

    var body: some View {
        GeometryReader { proxy in
            if let step = tutorialManager.currentStep {
                let targetRect = tutorialManager.anchors[step.anchorID].map { proxy[$0] }
                let placement = placement(for: targetRect, in: proxy)

                ZStack {
                    dimmedBackground(targetRect: targetRect)

                    if let rect = targetRect {
                        spotlightRing(rect: rect)
                    }

                    card(for: step, placement: placement, targetRect: targetRect, in: proxy)
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: step.id)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    // MARK: - Dimmed background with cutout

    @ViewBuilder
    private func dimmedBackground(targetRect: CGRect?) -> some View {
        ZStack {
            Color.black.opacity(0.65)
            if let rect = targetRect {
                RoundedRectangle(cornerRadius: 16)
                    .frame(width: rect.width + spotlightPadding * 2, height: rect.height + spotlightPadding * 2)
                    .position(x: rect.midX, y: rect.midY)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
        .contentShape(Rectangle())
        // Blocks every touch on the real UI underneath — including the highlighted
        // element itself — so a highlighted SOS button can't be tapped by accident.
        .accessibilityHidden(true)
    }

    private func spotlightRing(rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white, lineWidth: 3)
            .frame(width: rect.width + spotlightPadding * 2, height: rect.height + spotlightPadding * 2)
            .position(x: rect.midX, y: rect.midY)
            .shadow(color: .black.opacity(0.3), radius: 6)
            .allowsHitTesting(false)
    }

    // MARK: - Placement

    private func placement(for targetRect: CGRect?, in proxy: GeometryProxy) -> Placement {
        guard let rect = targetRect else { return .centered }
        let spaceBelow = proxy.size.height - rect.maxY
        let spaceAbove = rect.minY
        let neededSpace = measuredCardSize.height + cardTargetSpacing
        if spaceBelow >= neededSpace { return .below }
        if spaceAbove >= neededSpace { return .above }
        return spaceBelow > spaceAbove ? .below : .above
    }

    // MARK: - Card

    @ViewBuilder
    private func card(for step: TutorialStep, placement: Placement, targetRect: CGRect?, in proxy: GeometryProxy) -> some View {
        let x = clampedX(for: targetRect, in: proxy)
        let y = clampedY(for: placement, targetRect: targetRect, in: proxy)
        // The card's own x gets clamped to stay on-screen, which can leave it
        // off-center from the target (e.g. SOS sitting near the screen edge).
        // Nudge just the pointer so its tip still lines up with the target.
        let pointerOffset = pointerOffsetX(for: targetRect, cardCenterX: x)

        VStack(spacing: 0) {
            if placement == .below {
                pointer(pointingUp: true)
                    .offset(x: pointerOffset)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(step.title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.black)

                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button {
                        tutorialManager.skip(appState: appState)
                    } label: {
                        Text("Skip")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                    }

                    Text("\(tutorialManager.currentStepIndex + 1)/\(tutorialManager.totalSteps)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .accessibilityLabel(appState.text(
                            "Langkah \(tutorialManager.currentStepIndex + 1) dari \(tutorialManager.totalSteps)",
                            "Step \(tutorialManager.currentStepIndex + 1) of \(tutorialManager.totalSteps)"
                        ))
                        .padding(.leading, 8)

                    Spacer()

                    Button {
                        tutorialManager.advance(appState: appState)
                    } label: {
                        Text(step.buttonTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(Color.black))
                    }
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)

            if placement == .above {
                pointer(pointingUp: false)
                    .offset(x: pointerOffset)
            }
        }
        .frame(maxWidth: cardMaxWidth)
        .background(
            GeometryReader { cardProxy in
                Color.clear.preference(key: TutorialCardSizePreferenceKey.self, value: cardProxy.size)
            }
        )
        .onPreferenceChange(TutorialCardSizePreferenceKey.self) { measuredCardSize = $0 }
        .position(x: x, y: y)
        .accessibilityElement(children: .combine)
        .accessibilityFocused($isCardFocused)
        .accessibilityAddTraits(.isModal)
        .onAppear { focusCardShortly() }
        .onChange(of: step.id) { _, _ in focusCardShortly() }
    }

    private func focusCardShortly() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isCardFocused = true
        }
    }

    private func pointer(pointingUp: Bool) -> some View {
        TutorialPointerTriangle()
            .fill(Color.white)
            .frame(width: 22, height: 12)
            .rotationEffect(.degrees(pointingUp ? 0 : 180))
    }

    // MARK: - Position math (clamped so the card never leaves the screen)

    /// How far the pointer should shift from the card's horizontal center to
    /// keep pointing at the target, clamped so it stays clear of the card's
    /// rounded corners.
    private func pointerOffsetX(for targetRect: CGRect?, cardCenterX: CGFloat) -> CGFloat {
        guard let rect = targetRect else { return 0 }
        let desiredOffset = rect.midX - cardCenterX
        let maxOffset = max(measuredCardSize.width / 2 - 20, 0)
        return min(max(desiredOffset, -maxOffset), maxOffset)
    }

    private func clampedX(for targetRect: CGRect?, in proxy: GeometryProxy) -> CGFloat {
        let halfWidth = min(cardMaxWidth, proxy.size.width - screenEdgeMargin * 2) / 2
        let minX = screenEdgeMargin + halfWidth
        let maxX = proxy.size.width - screenEdgeMargin - halfWidth
        guard maxX >= minX else { return proxy.size.width / 2 }
        let desiredX = targetRect?.midX ?? proxy.size.width / 2
        return min(max(desiredX, minX), maxX)
    }

    private func clampedY(for placement: Placement, targetRect: CGRect?, in proxy: GeometryProxy) -> CGFloat {
        let halfHeight = measuredCardSize.height / 2
        let topInset = proxy.safeAreaInsets.top + screenEdgeMargin
        let bottomInset = proxy.safeAreaInsets.bottom + screenEdgeMargin
        let minY = topInset + halfHeight
        let maxY = proxy.size.height - bottomInset - halfHeight

        guard let rect = targetRect else {
            return proxy.size.height / 2
        }

        let desiredY: CGFloat
        switch placement {
        case .below:
            desiredY = rect.maxY + spotlightPadding + cardTargetSpacing + halfHeight
        case .above:
            desiredY = rect.minY - spotlightPadding - cardTargetSpacing - halfHeight
        case .centered:
            desiredY = proxy.size.height / 2
        }

        guard maxY >= minY else { return proxy.size.height / 2 }
        return min(max(desiredY, minY), maxY)
    }
}

private struct TutorialCardSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 280, height: 170)
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct TutorialPointerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
