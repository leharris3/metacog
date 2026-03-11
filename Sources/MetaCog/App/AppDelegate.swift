import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hudPanel: HUDPanel?
    private let appState = AppState.shared
    private var cancellables = Set<AnyCancellable>()

    private var planningWindow: NSWindow?
    private var debriefWindow: NSWindow?
    private var resumeWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Prevent macOS window restoration from reopening Settings/Dashboard
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibilityPermissions()

        // Initialize singletons
        _ = DatabaseManager.shared
        _ = TimeTracker.shared
        _ = InterventionManager.shared
        _ = CheckInScheduler.shared

        // Check for interrupted task
        checkForInterruptedTask()

        // Create HUD
        setupHUD()

        // Set up observers for planning-related windows (dropFirst skips initial value)
        setupWindowObservers()

        // Handle initial interrupted task state explicitly
        if appState.hasInterruptedTask {
            showResumeWindow()
        }

        // Close any windows auto-restored by macOS (e.g. Settings, Dashboard).
        // We observe didFinishRestoringWindowsNotification because SwiftUI scene
        // restoration completes after applicationDidFinishLaunching returns, so a
        // plain DispatchQueue.main.async fires too early to catch restored windows.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishRestoringWindowsNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                NSApp.windows
                    .filter { $0.title == "Settings" || $0.title == "Dashboard" }
                    .forEach { $0.close() }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Auto-pause active task on quit
        if let task = appState.currentTask, task.status == .active {
            TimeTracker.shared.stopTracking()
            CheckInScheduler.shared.stopMonitoring()

            var paused = task
            paused.status = .paused
            paused.actualDuration = appState.elapsedTime
            try? DatabaseManager.shared.updateTask(paused)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Window Observers

    private func setupWindowObservers() {
        appState.$showingPlanningWizard
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                MainActor.assumeIsolated {
                    if showing { self?.showPlanningWindow() }
                    else { self?.closePlanningWindow() }
                }
            }
            .store(in: &cancellables)

        appState.$showingDebrief
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                MainActor.assumeIsolated {
                    if showing { self?.showDebriefWindow() }
                    else { self?.closeDebriefWindow() }
                }
            }
            .store(in: &cancellables)

        appState.$hasInterruptedTask
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                MainActor.assumeIsolated {
                    if showing { self?.showResumeWindow() }
                    else { self?.closeResumeWindow() }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Planning Windows

    private func makeTransientWindow(size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        return window
    }

    /// Force-activate MetaCog, make the window key, and set first responder
    /// so SwiftUI text fields receive keyboard input.
    ///
    /// On macOS 14+, `activate(ignoringOtherApps:)` is deprecated and the
    /// `ignoringOtherApps` parameter has no effect. To reliably grab focus
    /// when our windows are triggered from a `.nonActivatingPanel` (HUD) or
    /// from an app-switch handler, we:
    ///   1. Ensure the activation policy is `.regular` so the app is eligible
    ///      for activation.
    ///   2. Call `NSApp.activate()` (the modern API).
    ///   3. Use `orderFrontRegardless()` to bring the window above all others.
    ///   4. Set the first responder to the content view so the SwiftUI
    ///      responder chain receives keyboard events.
    ///   5. Retry after a short delay to win any focus race with the
    ///      previously-active app or a sheet dismiss animation.
    private func forceKeyWindow(_ window: NSWindow) {
        // Ensure the app is eligible for activation — the HUD-only state
        // (all titled windows closed) can leave the policy at .accessory.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        if let contentView = window.contentView {
            window.makeFirstResponder(contentView)
        }
        // Guard against residual window-server focus shuffling with a
        // delayed re-activation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.activate()
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            if let contentView = window.contentView {
                window.makeFirstResponder(contentView)
            }
        }
    }

    private func showPlanningWindow() {
        guard planningWindow == nil else {
            forceKeyWindow(planningWindow!)
            return
        }
        let window = makeTransientWindow(size: NSSize(width: 520, height: 480))
        let view = PlanningWizardView().environmentObject(appState)
        window.contentView = NSHostingView(rootView: view)
        planningWindow = window
        forceKeyWindow(window)
    }

    private func closePlanningWindow() {
        planningWindow?.close()
        planningWindow = nil
    }

    private func showDebriefWindow() {
        guard debriefWindow == nil else {
            forceKeyWindow(debriefWindow!)
            return
        }
        let window = makeTransientWindow(size: NSSize(width: 520, height: 560))
        let view = DebriefView().environmentObject(appState)
        window.contentView = NSHostingView(rootView: view)
        debriefWindow = window
        forceKeyWindow(window)
    }

    private func closeDebriefWindow() {
        debriefWindow?.close()
        debriefWindow = nil
    }

    private func showResumeWindow() {
        guard resumeWindow == nil else {
            forceKeyWindow(resumeWindow!)
            return
        }
        let window = makeTransientWindow(size: NSSize(width: 380, height: 280))
        let view = ResumeTaskPrompt().environmentObject(appState)
        window.contentView = NSHostingView(rootView: view)
        resumeWindow = window
        forceKeyWindow(window)
    }

    private func closeResumeWindow() {
        resumeWindow?.close()
        resumeWindow = nil
    }

    // MARK: - Setup

    private func checkAccessibilityPermissions() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            print("MetaCog requires Accessibility permissions for app-switch detection.")
        }
    }

    private func checkForInterruptedTask() {
        guard let task = try? DatabaseManager.shared.fetchPausedTask() else { return }
        appState.currentTask = task
        appState.loadTaskData()
        appState.hasInterruptedTask = true
    }

    private func setupHUD() {
        hudPanel = HUDPanel(appState: appState)
        hudPanel?.orderFront(nil)
    }
}
