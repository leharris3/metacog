import AppKit

/// Manages the persistent menu bar status item (white cog icon).
///
/// **Left-click** toggles HUD panel visibility.
/// **Right-click** shows a quick-actions menu (New Task, Pause/Resume, Dashboard, Settings, Quit).
///
/// Initialized once by `AppDelegate` after the HUD is created. Holds a weak reference to the
/// HUD panel and a strong reference to AppState for reading current task status.
@MainActor
final class MenuBarManager {

    // MARK: - Properties

    /// The persistent status bar item. Retained for the app's lifetime.
    private var statusItem: NSStatusItem?

    /// Weak reference to the HUD panel managed by AppDelegate.
    /// Used to toggle visibility on left-click.
    private weak var hudPanel: HUDPanel?

    /// Central app state — read to determine which menu items to show.
    private let appState: AppState

    /// Callback to open the Dashboard window (requires SwiftUI `openWindow` environment).
    /// Set by AppDelegate since MenuBarManager doesn't have access to SwiftUI environments.
    var openDashboard: (() -> Void)?

    /// Callback to open the Settings window.
    var openSettings: (() -> Void)?

    // MARK: - Initialization

    /// Creates the menu bar status item and wires up click handlers.
    ///
    /// - Parameters:
    ///   - hudPanel: The HUD panel to toggle on left-click.
    ///   - appState: The shared app state for reading task status.
    init(hudPanel: HUDPanel, appState: AppState) {
        self.hudPanel = hudPanel
        self.appState = appState
        setupStatusItem()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }

        // White cog icon — uses SF Symbols which are available on macOS 11+.
        button.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "MetaCog")
        button.image?.isTemplate = true  // Adapts to light/dark menu bar automatically

        // Listen for both left and right mouse-up so we can differentiate click type.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(statusItemClicked(_:))
        button.target = self
    }

    // MARK: - Click Handling

    /// Routes left-click to HUD toggle, right-click to quick-actions menu.
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showQuickActionsMenu()
        } else {
            toggleHUD()
        }
    }

    /// Shows or hides the HUD panel.
    private func toggleHUD() {
        guard let hud = hudPanel else { return }

        if hud.isVisible {
            hud.orderOut(nil)
        } else {
            hud.orderFront(nil)
        }
    }

    // MARK: - Quick Actions Menu

    /// Builds and displays the right-click context menu below the status item.
    ///
    /// Menu contents adapt to current state:
    /// - "New Task" (disabled when a task is active)
    /// - "Pause" / "Resume" (only shown when a task exists)
    /// - Separator
    /// - "Open Dashboard"
    /// - "Settings"
    /// - Separator
    /// - "Quit MetaCog"
    private func showQuickActionsMenu() {
        let menu = NSMenu()

        // --- Task Actions ---

        let newTaskItem = NSMenuItem(
            title: "New Task",
            action: #selector(newTaskAction),
            keyEquivalent: ""
        )
        newTaskItem.target = self
        // Disable "New Task" when a task is already active or paused.
        newTaskItem.isEnabled = appState.currentTask == nil
        menu.addItem(newTaskItem)

        if let task = appState.currentTask {
            if task.status == .active {
                let pauseItem = NSMenuItem(
                    title: "Pause",
                    action: #selector(pauseAction),
                    keyEquivalent: ""
                )
                pauseItem.target = self
                menu.addItem(pauseItem)
            } else if task.status == .paused {
                let resumeItem = NSMenuItem(
                    title: "Resume",
                    action: #selector(resumeAction),
                    keyEquivalent: ""
                )
                resumeItem.target = self
                menu.addItem(resumeItem)
            }
        }

        menu.addItem(.separator())

        // --- Navigation ---

        let dashboardItem = NSMenuItem(
            title: "Open Dashboard",
            action: #selector(dashboardAction),
            keyEquivalent: ""
        )
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(settingsAction),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // --- App Lifecycle ---

        let quitItem = NSMenuItem(
            title: "Quit MetaCog",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // Display the menu anchored below the status item.
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        // Clear the menu after display so left-clicks aren't intercepted by it.
        statusItem?.menu = nil
    }

    // MARK: - Menu Actions

    @objc private func newTaskAction() {
        appState.showingPlanningWizard = true
    }

    @objc private func pauseAction() {
        appState.pauseTask()
    }

    @objc private func resumeAction() {
        appState.resumeTask()
    }

    @objc private func dashboardAction() {
        openDashboard?()
    }

    @objc private func settingsAction() {
        openSettings?()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
