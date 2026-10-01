//
//  TutorialManager.swift
//  safeOne
//

import SwiftUI
import Combine

struct TutorialStep: Identifiable {
    let id: String
    let anchorID: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    /// Side effect to run when this step becomes current — e.g. switching tabs
    /// so the real target it needs to highlight is actually on screen.
    let onActivate: ((AppState) -> Void)?

    init(
        anchorID: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        buttonTitle: LocalizedStringKey,
        onActivate: ((AppState) -> Void)? = nil
    ) {
        self.id = anchorID
        self.anchorID = anchorID
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.onActivate = onActivate
    }
}

enum TutorialRole: String {
    case elder
    case child
}

/// Drives the first-run coachmark tutorial for both the Elder and Child roles.
/// Shared as an `@EnvironmentObject` from `safeOneApp` so any screen can trigger
/// or advance it, while `TutorialOverlayView` renders whatever is currently active.
@MainActor
final class TutorialManager: ObservableObject {
    @Published private(set) var isActive: Bool = false
    @Published private(set) var currentStepIndex: Int = 0
    @Published var anchors: [String: Anchor<CGRect>] = [:]

    private var steps: [TutorialStep] = []
    private var activeRole: TutorialRole?

    var currentStep: TutorialStep? {
        guard steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    var totalSteps: Int { steps.count }

    // MARK: - Elder steps (3)

    private static let elderSteps: [TutorialStep] = [
        TutorialStep(
            anchorID: "elder.reminders",
            title: "Your Reminders",
            description: "See your upcoming reminders here. Your caregiver can help you keep track of important daily activities and medication reminders.",
            buttonTitle: "Next",
            onActivate: { appState in appState.elderTabSelection = .dashboard }
        ),
        TutorialStep(
            anchorID: "elder.sos",
            title: "Emergency SOS",
            description: "Need help? Tap SOS to quickly contact your caregiver.",
            buttonTitle: "Next"
        ),
        TutorialStep(
            anchorID: "elder.connectCode",
            title: "Connect With Your Caregiver",
            description: "Generate your code and share it with your caregiver so they can connect to your account.",
            buttonTitle: "Done",
            onActivate: { appState in appState.elderTabSelection = .profile }
        )
    ]

    // MARK: - Child steps (4)

    private static let childSteps: [TutorialStep] = [
        TutorialStep(
            anchorID: "child.elders",
            title: "Your Elders",
            description: "See the elders you're helping. You can connect and manage more than one elder from here.",
            buttonTitle: "Next",
            onActivate: { appState in appState.childTabSelection = .dashboard }
        ),
        TutorialStep(
            anchorID: "child.elders",
            title: "Switch Between Elders",
            description: "Select an elder to view their reminders, information, and settings.",
            buttonTitle: "Next"
        ),
        TutorialStep(
            anchorID: "child.reminders.add",
            title: "Manage Reminders",
            description: "Create and manage reminders to help your elder stay on track with important daily activities.",
            buttonTitle: "Next",
            onActivate: { appState in appState.childTabSelection = .reminders }
        ),
        TutorialStep(
            anchorID: "child.connectElder",
            title: "Connect an Elder",
            description: "Use a code to connect an elder to your account and start helping them.",
            buttonTitle: "Done",
            onActivate: { appState in appState.childTabSelection = .profile }
        )
    ]

    // MARK: - Persistence (per-user, not global)

    private func completionKey(role: TutorialRole, userId: String) -> String {
        "\(role.rawValue)TutorialCompleted_\(userId)"
    }

    private func isCompleted(role: TutorialRole, userId: String) -> Bool {
        UserDefaults.standard.bool(forKey: completionKey(role: role, userId: userId))
    }

    private func markCompleted(role: TutorialRole, userId: String) {
        UserDefaults.standard.set(true, forKey: completionKey(role: role, userId: userId))
    }

    // MARK: - Lifecycle

    func startElderTutorialIfNeeded(appState: AppState) {
        guard let user = appState.currentUser, user.role.lowercased() == "elder" else { return }
        guard !isActive, !isCompleted(role: .elder, userId: user.id) else { return }
        start(role: .elder, steps: Self.elderSteps, appState: appState)
    }

    func startChildTutorialIfNeeded(appState: AppState) {
        guard let user = appState.currentUser, user.role.lowercased() == "child" else { return }
        guard !isActive, !isCompleted(role: .child, userId: user.id) else { return }
        start(role: .child, steps: Self.childSteps, appState: appState)
    }

    private func start(role: TutorialRole, steps: [TutorialStep], appState: AppState) {
        // Deliberately NOT clearing `anchors` here: the target screen (e.g. the
        // Dashboard tab) is usually already rendered and has already reported its
        // anchors via preference by the time this runs. Wiping the dictionary would
        // discard that and nothing would re-trigger those anchors to be reported
        // again unless something else forces that screen to re-render.
        self.steps = steps
        self.activeRole = role
        self.currentStepIndex = 0
        self.isActive = true
        steps.first?.onActivate?(appState)
    }

    func advance(appState: AppState) {
        guard isActive else { return }
        let nextIndex = currentStepIndex + 1
        if steps.indices.contains(nextIndex) {
            currentStepIndex = nextIndex
            steps[nextIndex].onActivate?(appState)
        } else {
            finish(appState: appState)
        }
    }

    /// Ends the tutorial early, e.g. from a "Skip" button. Marks it completed
    /// just like finishing normally, so it won't be shown again.
    func skip(appState: AppState) {
        guard isActive else { return }
        finish(appState: appState)
    }

    private func finish(appState: AppState) {
        if let role = activeRole, let userId = appState.currentUser?.id {
            markCompleted(role: role, userId: userId)
        }
        isActive = false
        activeRole = nil
        currentStepIndex = 0
        steps = []
        anchors = [:]
    }
}
