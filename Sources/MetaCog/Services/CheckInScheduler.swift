import AppKit
import SwiftUI

/// Monitors elapsed time against sub-goal estimates and triggers check-in prompts
/// at 50% and 90% of each sub-goal's estimated duration.
@MainActor
final class CheckInScheduler: ObservableObject {
    static let shared = CheckInScheduler()

    @Published var pendingCheckIn: PendingCheckIn?

    private var checkInWindow: NSWindow?

    /// Tracks which check-ins have already been shown: [subGoalId: Set<threshold>]
    private var shownCheckIns: [UUID: Set<Double>] = [:]

    private var pollTimer: Timer?

    struct PendingCheckIn {
        let subGoal: SubGoal
        let threshold: Double  // 0.5 or 0.9
    }

    private init() {}

    func startMonitoring() {
        shownCheckIns = [:]
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForDueCheckIns()
            }
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        shownCheckIns = [:]
        dismissCheckInWindow()
    }

    func resetForNewTask() {
        stopMonitoring()
        startMonitoring()
    }

    private func checkForDueCheckIns() {
        let appState = AppState.shared
        guard appState.currentTask?.status == .active else { return }
        guard pendingCheckIn == nil else { return }  // Already showing one

        let elapsed = appState.elapsedTime
        var cumulativeTime: TimeInterval = 0

        for goal in appState.subGoals {
            guard !goal.isCompleted else {
                cumulativeTime += goal.estimatedDuration
                continue
            }
            guard goal.estimatedDuration > 0 else {
                cumulativeTime += goal.estimatedDuration
                continue
            }

            let goalElapsed = elapsed - cumulativeTime
            let ratio = goalElapsed / goal.estimatedDuration

            let shown = shownCheckIns[goal.id] ?? []

            if ratio >= 0.5 && !shown.contains(0.5) {
                triggerCheckIn(for: goal, threshold: 0.5)
                return
            }
            if ratio >= 0.9 && !shown.contains(0.9) {
                triggerCheckIn(for: goal, threshold: 0.9)
                return
            }

            // Only check the current (first incomplete) sub-goal
            break
        }
    }

    private func triggerCheckIn(for goal: SubGoal, threshold: Double) {
        shownCheckIns[goal.id, default: []].insert(threshold)
        pendingCheckIn = PendingCheckIn(subGoal: goal, threshold: threshold)
        showCheckInWindow()
    }

    func completeCheckIn(isCompleted: Bool, reflection: String?, amendments: String?) {
        guard let pending = pendingCheckIn else { return }
        let appState = AppState.shared

        // Determine current foreground app
        let frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"

        let checkIn = CheckIn(
            subGoalId: pending.subGoal.id,
            isCompleted: isCompleted,
            reflection: reflection,
            foregroundApp: frontApp,
            elapsedTime: appState.elapsedTime,
            amendmentsMade: amendments
        )
        try? DatabaseManager.shared.createCheckIn(checkIn)

        if isCompleted {
            appState.completeSubGoal(pending.subGoal)
        }

        pendingCheckIn = nil
        dismissCheckInWindow()
    }

    // MARK: - Window

    private func showCheckInWindow() {
        guard let pending = pendingCheckIn else { return }

        let view = CheckInPromptView(
            subGoalTitle: pending.subGoal.title,
            threshold: pending.threshold
        )
        .environmentObject(self)
        .environmentObject(AppState.shared)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Prevent close() from releasing the window — ARC owns it.
        window.isReleasedWhenClosed = false
        window.level = .floating + 1
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        checkInWindow = window
    }

    private func dismissCheckInWindow() {
        checkInWindow?.close()
        checkInWindow = nil
    }
}
