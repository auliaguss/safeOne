//
//  TutorialAnchorPreference.swift
//  safeOne
//

import SwiftUI

/// Collects the on-screen bounds of every view tagged with `.tutorialAnchor(_:)`,
/// keyed by anchor id, so `TutorialOverlayView` can spotlight the real component
/// instead of a hardcoded position.
struct TutorialAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Tags this view as a tutorial target. `id` must match a `TutorialStep.anchorID`.
    func tutorialAnchor(_ id: String) -> some View {
        anchorPreference(key: TutorialAnchorPreferenceKey.self, value: .bounds) { anchor in
            [id: anchor]
        }
    }
}
