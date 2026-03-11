import AppKit
import SwiftUI

/// Manages the intervention flow when an unauthorized app switch is detected.
@MainActor
final class InterventionManager: ObservableObject {
    static let shared = InterventionManager()

    @Published var isShowingIntervention = false
    @Published var interventionPhase: InterventionPhase = .timer
    @Published var remainingPenalty: TimeInterval = 0
    @Published var currentAnkiCard: AnkiCard?
    @Published var overridesRemaining: Int = 3
    @Published var unauthorizedAppName: String = ""

    private var penaltyTimer: Timer?
    private var unauthorizedBundleId: String = ""
    private var interventionWindow: NSWindow?
    private var refocusTarget: NSRunningApplication?

    enum InterventionPhase {
        case timer
        case anki
        case complete
    }

    private init() {}

    func triggerIntervention(unauthorizedApp: String, appName: String, refocusTarget: NSRunningApplication? = nil) {
        let appState = AppState.shared

        // If there's an active task, check linked groups
        if let task = appState.currentTask, task.status == .active {
            if isInSameLinkedGroup(bundleId: unauthorizedApp) {
                return
            }
        }

        // Don't stack interventions
        if isShowingIntervention { return }

        unauthorizedBundleId = unauthorizedApp
        unauthorizedAppName = appName
        self.refocusTarget = refocusTarget
        let penalty = appState.currentPenaltyDuration
        remainingPenalty = penalty

        // Load override budget
        let override = try? DatabaseManager.shared.fetchOrCreateDailyOverride()
        overridesRemaining = override?.remainingOverrides ?? 0

        interventionPhase = .timer
        isShowingIntervention = true

        showInterventionWindow()
        startPenaltyTimer()
    }

    private func isInSameLinkedGroup(bundleId: String) -> Bool {
        let appState = AppState.shared
        let perms = appState.appPermissions

        // Find the permission for the new app (if it even has one — it shouldn't, since it's unauthorized)
        // Actually, check if it shares a group with any permitted app
        guard let currentApp = perms.first(where: { $0.bundleIdentifier == bundleId }) else {
            return false
        }
        guard let groupId = currentApp.linkedGroupId else { return false }

        // If any other permitted app shares this group, it's a free switch
        return perms.contains { $0.linkedGroupId == groupId && $0.bundleIdentifier != bundleId }
    }

    private func startPenaltyTimer() {
        penaltyTimer?.invalidate()
        penaltyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.penaltyTick()
            }
        }
    }

    private func penaltyTick() {
        remainingPenalty -= 1
        if remainingPenalty <= 0 {
            penaltyTimer?.invalidate()
            penaltyTimer = nil
            advanceToAnkiPhase()
        }
    }

    private func advanceToAnkiPhase() {
        let dueCards = (try? DatabaseManager.shared.fetchDueAnkiCards()) ?? []
        if dueCards.isEmpty {
            completeIntervention(wasOverridden: false)
        } else {
            currentAnkiCard = dueCards.randomElement()
            interventionPhase = .anki
        }
    }

    func handleAnkiAnswer(correct: Bool) {
        guard var card = currentAnkiCard else { return }
        let appState = AppState.shared

        // Record the intervention
        if let task = appState.currentTask {
            let intervention = Intervention(
                taskId: task.id,
                type: .anki,
                penaltyDuration: appState.currentPenaltyDuration,
                ankiCardId: card.id,
                wasCorrect: correct
            )
            try? DatabaseManager.shared.createIntervention(intervention)
        }

        // Update card with SM-2
        card.review(quality: correct ? 4 : 1)
        try? DatabaseManager.shared.updateAnkiCard(card)

        if correct {
            completeIntervention(wasOverridden: false)
        } else {
            // Show another card
            let dueCards = (try? DatabaseManager.shared.fetchDueAnkiCards()) ?? []
            let allCards = (try? DatabaseManager.shared.fetchAllAnkiCards()) ?? []
            let candidates = dueCards.isEmpty ? allCards : dueCards
            currentAnkiCard = candidates.filter({ $0.id != card.id }).randomElement() ?? candidates.first
        }
    }

    func useOverride() {
        let success = (try? DatabaseManager.shared.useOverride()) ?? false
        if success {
            // Log intervention as overridden
            if let task = AppState.shared.currentTask {
                let intervention = Intervention(
                    taskId: task.id,
                    type: .timer,
                    penaltyDuration: AppState.shared.currentPenaltyDuration,
                    wasOverridden: true
                )
                try? DatabaseManager.shared.createIntervention(intervention)
            }
            completeIntervention(wasOverridden: true)
        }
    }

    /// Dismiss the intervention without penalty (e.g., user returned to a permitted app).
    func cancelIntervention() {
        penaltyTimer?.invalidate()
        penaltyTimer = nil
        interventionPhase = .complete
        isShowingIntervention = false
        dismissInterventionWindow()
    }

    private func completeIntervention(wasOverridden: Bool) {
        penaltyTimer?.invalidate()
        penaltyTimer = nil

        if !wasOverridden {
            // Log timer-only intervention if we didn't already log an anki one
            if interventionPhase == .timer, let task = AppState.shared.currentTask {
                let intervention = Intervention(
                    taskId: task.id,
                    type: .timer,
                    penaltyDuration: AppState.shared.currentPenaltyDuration
                )
                try? DatabaseManager.shared.createIntervention(intervention)
            }
        }

        // Increment intervention count for exponential escalation
        AppState.shared.interventionCount += 1

        // IMPORTANT: We must defer ALL state changes below to the next
        // run-loop turn. Here's why:
        //
        // This function is called synchronously from a SwiftUI Button
        // action closure (e.g. the "Correct" / "Incorrect" / "Skip"
        // buttons in InterventionOverlayView). If we set
        // `interventionPhase = .complete` synchronously, SwiftUI
        // immediately re-evaluates the view body. The `switch` on
        // `interventionPhase` now yields `EmptyView()`, which tears
        // down the ankiPhaseView — including the very Button whose
        // action closure is still on the call stack. Accessing the
        // now-deallocated view state causes a bad-pointer dereference
        // (SIGSEGV / Signal 11).
        //
        // Wrapping the mutations in `Task { @MainActor in … }` pushes
        // them to after the current synchronous call stack unwinds,
        // so the Button action completes cleanly before the view tree
        // is modified.
        Task { @MainActor in
            self.interventionPhase = .complete
            self.isShowingIntervention = false
            self.dismissInterventionWindow()
            // Return the user to the last permitted app so they can resume work.
            // TimeTracker no longer pre-activates the refocusTarget (to avoid
            // stealing keyboard focus from the intervention window), so we
            // activate it here instead once the intervention is fully dismissed.
            if let target = self.refocusTarget {
                Accessibility.activateApp(target)
            }
        }
    }

    // MARK: - Window Management

    private func showInterventionWindow() {
        let view = InterventionOverlayView()
            .environmentObject(self)
            .environmentObject(AppState.shared)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 720),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Under ARC, close() must NOT also release the window — ARC
        // manages the lifetime. Without this, close() sends an extra
        // release, and the subsequent `interventionWindow = nil` causes
        // a double-free (crash in objc_autoreleasePoolPop).
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovable = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: view)
        window.center()
        interventionWindow = window

        // Force-activate MetaCog and make the intervention window key so it
        // receives keyboard focus. On macOS 14+, activate(ignoringOtherApps:)
        // is deprecated with no effect, so we ensure a .regular activation
        // policy and use the modern NSApp.activate().
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        if let contentView = window.contentView {
            window.makeFirstResponder(contentView)
        }
        let w = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.activate()
            w.orderFrontRegardless()
            w.makeKeyAndOrderFront(nil)
            if let contentView = w.contentView {
                w.makeFirstResponder(contentView)
            }
        }
    }

    private func dismissInterventionWindow() {
        interventionWindow?.close()
        interventionWindow = nil
    }
}
