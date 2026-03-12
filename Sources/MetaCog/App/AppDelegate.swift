import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hudPanel: HUDPanel?
    private var menuBarManager: MenuBarManager?
    private let appState = AppState.shared
    private var cancellables = Set<AnyCancellable>()

    private var planningWindow: NSWindow?
    private var projectWizardWindow: NSWindow?
    private var debriefWindow: NSWindow?
    private var resumeWindow: NSWindow?
    private var ankiGateWindow: NSWindow?
    private var projectDebriefWindow: NSWindow?

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

        // Create HUD and menu bar icon
        setupHUD()
        setupMenuBar()

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

        appState.$showingAnkiGate
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                MainActor.assumeIsolated {
                    if showing { self?.showAnkiGateWindow() }
                    else { self?.closeAnkiGateWindow() }
                }
            }
            .store(in: &cancellables)

        appState.$showingProjectWizard
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                MainActor.assumeIsolated {
                    if showing { self?.showProjectWizardWindow() }
                    else { self?.closeProjectWizardWindow() }
                }
            }
            .store(in: &cancellables)

        appState.$showingProjectDebrief
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                MainActor.assumeIsolated {
                    if showing { self?.showProjectDebriefWindow() }
                    else { self?.closeProjectDebriefWindow() }
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

    // MARK: - Anki Gate Window

    private func showAnkiGateWindow() {
        guard ankiGateWindow == nil else {
            forceKeyWindow(ankiGateWindow!)
            return
        }
        let window = makeTransientWindow(size: NSSize(width: 480, height: 440))
        let view = AnkiGateView().environmentObject(appState)
        window.contentView = NSHostingView(rootView: view)
        ankiGateWindow = window
        forceKeyWindow(window)
    }

    private func closeAnkiGateWindow() {
        ankiGateWindow?.close()
        ankiGateWindow = nil
    }

    // MARK: - Project Wizard Window

    private func showProjectWizardWindow() {
        guard projectWizardWindow == nil else {
            forceKeyWindow(projectWizardWindow!)
            return
        }
        let window = makeTransientWindow(size: NSSize(width: 560, height: 600))
        let view = ProjectWizardView().environmentObject(appState)
        window.contentView = NSHostingView(rootView: view)
        projectWizardWindow = window
        forceKeyWindow(window)
    }

    private func closeProjectWizardWindow() {
        projectWizardWindow?.close()
        projectWizardWindow = nil
    }

    // MARK: - Project Debrief Window

    private func showProjectDebriefWindow() {
        guard projectDebriefWindow == nil else {
            forceKeyWindow(projectDebriefWindow!)
            return
        }
        let window = makeTransientWindow(size: NSSize(width: 520, height: 560))
        let view = ProjectDebriefView().environmentObject(appState)
        window.contentView = NSHostingView(rootView: view)
        projectDebriefWindow = window
        forceKeyWindow(window)
    }

    private func closeProjectDebriefWindow() {
        projectDebriefWindow?.close()
        projectDebriefWindow = nil
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
        // Restore any active/paused project.
        if let project = try? DatabaseManager.shared.fetchActiveProject() {
            appState.currentProject = project
        }

        guard let task = try? DatabaseManager.shared.fetchPausedTask() else { return }
        appState.currentTask = task
        appState.loadTaskData()
        appState.hasInterruptedTask = true
    }

    private func setupHUD() {
        hudPanel = HUDPanel(appState: appState)
        hudPanel?.orderFront(nil)
    }

    /// Creates the menu bar status item (white cog icon) with HUD toggle and quick actions.
    /// Must be called after `setupHUD()` so the HUD panel reference is available.
    ///
    /// Note: `openDashboard` and `openSettings` callbacks are wired later by `HUDContentView`
    /// via `configureMenuBarCallbacks()`, because those actions require SwiftUI's `openWindow`
    /// and `openSettings` environments which are only available inside SwiftUI views.
    private func setupMenuBar() {
        guard let hud = hudPanel else { return }
        menuBarManager = MenuBarManager(hudPanel: hud, appState: appState)

        // Settings can be opened via NSApp.sendAction from AppKit directly.
        menuBarManager?.openSettings = {
            NSApp.activate()
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    /// Called by `HUDContentView.onAppear` to wire SwiftUI environment actions
    /// (openWindow, openSettings) into the menu bar manager.
    func configureMenuBarCallbacks(openDashboard: @escaping () -> Void) {
        menuBarManager?.openDashboard = openDashboard
    }
}
