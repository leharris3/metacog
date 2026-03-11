import AppKit
import Combine

/// Tracks active foreground time for the current task.
/// Timer runs only when a permitted app is in the foreground, the task is active,
/// and the screen is not locked/idle.
@MainActor
final class TimeTracker: ObservableObject {
    static let shared = TimeTracker()

    private var timer: Timer?
    private var lastTickDate: Date?
    private var currentForegroundApp: String?
    private var currentAppUsageLogId: UUID?
    private var appUsageStartTime: Date?
    private var lastPermittedApp: NSRunningApplication?

    private nonisolated(unsafe) var workspaceObservers: [NSObjectProtocol] = []
    private nonisolated(unsafe) var distributedObservers: [NSObjectProtocol] = []

    private var screenLocked = false

    private init() {
        setupObservers()
    }

    deinit {
        for obs in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        for obs in distributedObservers {
            DistributedNotificationCenter.default().removeObserver(obs)
        }
    }

    // MARK: - Setup

    private func setupObservers() {
        let wsnc = NSWorkspace.shared.notificationCenter

        let activateObs = wsnc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier else { return }
            Task { @MainActor in
                self?.handleAppActivated(app: app, bundleId: bundleId, appName: app.localizedName ?? bundleId)
            }
        }
        workspaceObservers.append(activateObs)

        let deactivateObs = wsnc.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAppDeactivated()
            }
        }
        workspaceObservers.append(deactivateObs)

        // Screen lock/unlock
        let dnc = DistributedNotificationCenter.default()

        let lockObs = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.screenLocked = true
                self?.pauseTracking()
            }
        }
        distributedObservers.append(lockObs)

        let unlockObs = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.screenLocked = false
                if let self {
                    let appState = AppState.shared
                    if appState.isTimerRunning {
                        self.startTracking()
                    }
                }
            }
        }
        distributedObservers.append(unlockObs)
    }

    // MARK: - App Switch Handling

    private func handleAppActivated(app: NSRunningApplication, bundleId: String, appName: String) {
        let appState = AppState.shared
        currentForegroundApp = bundleId

        // Check if this is MetaCog itself — always allowed
        if bundleId == Bundle.main.bundleIdentifier {
            return
        }

        // If no active task, block all app usage
        guard let task = appState.currentTask, task.status == .active else {
            pauseTracking()
            InterventionManager.shared.triggerIntervention(
                unauthorizedApp: bundleId,
                appName: appName,
                refocusTarget: NSRunningApplication.current
            )
            return
        }

        let isPermitted = appState.appPermissions.contains { $0.bundleIdentifier == bundleId }

        if isPermitted {
            lastPermittedApp = app
            startTracking(bundleId: bundleId, appName: appName)
            // User switched to a permitted app — dismiss any active intervention
            // since they've voluntarily returned to work.
            if InterventionManager.shared.isShowingIntervention {
                InterventionManager.shared.cancelIntervention()
            }
        } else {
            // Don't activate the refocusTarget here — doing so hands keyboard
            // focus to the permitted app, which makes the intervention window's
            // text field (Anki answer) unable to receive keystrokes even though
            // it's visually on top at .screenSaver level.  Instead we just
            // pause tracking and let the intervention window activate MetaCog
            // itself.  The refocusTarget is passed through so InterventionManager
            // can re-activate it once the intervention completes.
            let refocusTarget = lastPermittedApp ?? NSRunningApplication.current

            pauseTracking()
            InterventionManager.shared.triggerIntervention(
                unauthorizedApp: bundleId,
                appName: appName,
                refocusTarget: refocusTarget
            )
        }
    }

    private func handleAppDeactivated() {
        finalizeCurrentAppUsage()
    }

    // MARK: - Timer Control

    func startTracking(bundleId: String? = nil, appName: String? = nil) {
        guard !screenLocked else { return }
        let appState = AppState.shared
        guard let task = appState.currentTask, task.status == .active else { return }

        if timer == nil {
            lastTickDate = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
        }

        // Start new app usage log if we have app info
        if let bundleId, let appName, currentAppUsageLogId == nil {
            appUsageStartTime = Date()
            let log = AppUsageLog(
                taskId: task.id,
                bundleIdentifier: bundleId,
                appName: appName,
                startTime: Date()
            )
            currentAppUsageLogId = log.id
            try? DatabaseManager.shared.createAppUsageLog(log)
        }
    }

    func pauseTracking() {
        timer?.invalidate()
        timer = nil
        finalizeCurrentAppUsage()
        persistElapsedTime()
        lastTickDate = nil
    }

    func stopTracking() {
        pauseTracking()
    }

    private func tick() {
        let appState = AppState.shared
        guard appState.isTimerRunning,
              let task = appState.currentTask,
              task.status == .active,
              !screenLocked else {
            pauseTracking()
            return
        }

        let now = Date()
        if let last = lastTickDate {
            let delta = now.timeIntervalSince(last)
            // Guard against large jumps (e.g., wake from sleep)
            if delta < 5 {
                appState.elapsedTime += delta
            }
        }
        lastTickDate = now
    }

    private func finalizeCurrentAppUsage() {
        guard let logId = currentAppUsageLogId,
              let startTime = appUsageStartTime else { return }

        let duration = Date().timeIntervalSince(startTime)
        var log = AppUsageLog(id: logId, taskId: UUID(), bundleIdentifier: "", appName: "", startTime: startTime, duration: duration)

        // Fetch and update the actual log
        if let task = AppState.shared.currentTask {
            let logs = (try? DatabaseManager.shared.fetchAppUsageLogs(forTask: task.id)) ?? []
            if var existing = logs.first(where: { $0.id == logId }) {
                existing.duration = duration
                try? DatabaseManager.shared.updateAppUsageLog(existing)
            }
        }

        currentAppUsageLogId = nil
        appUsageStartTime = nil
    }

    private func persistElapsedTime() {
        let appState = AppState.shared
        guard var task = appState.currentTask else { return }
        task.actualDuration = appState.elapsedTime
        try? DatabaseManager.shared.updateTask(task)
    }

    /// Called when app state changes (pause/resume/complete)
    func syncWithAppState() {
        let appState = AppState.shared
        if appState.isTimerRunning {
            if let bundleId = currentForegroundApp {
                let isPermitted = appState.appPermissions.contains { $0.bundleIdentifier == bundleId }
                if isPermitted {
                    startTracking()
                }
            }
        } else {
            pauseTracking()
        }
    }
}
