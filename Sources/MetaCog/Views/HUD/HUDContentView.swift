import SwiftUI

/// The main content of the always-visible HUD panel.
///
/// **Layout (top to bottom):**
/// 1. **Info row:** Current project name + task name on left; elapsed time + action icons on right.
/// 2. **Project timeline:** Task circles (proportional to duration) with a calendar-time triangle.
/// 3. **Sub-goal progress bar:** Segmented bar for the current task's sub-goals.
///
/// When no task is active, shows "No active task" and a "+" dropdown for creating tasks/projects.
///
/// **Height is dynamic:**
/// - Compact (80px): No active project — just the info row and sub-goal bar.
/// - Expanded (130px): Active/paused project — adds the project timeline row.
///
/// The HUD panel is resized and repositioned whenever the height changes,
/// keeping it anchored at bottom-center above the Dock.
struct HUDContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var showingEditor = false
    @State private var showingCreateMenu = false

    /// Whether the full project timeline visualization should be visible.
    /// True only when there's an active or paused project.
    private var hasActiveProject: Bool {
        guard let project = appState.currentProject else { return false }
        return project.status == .active || project.status == .paused
    }

    /// HUD height adapts to content: compact when no active project, expanded when showing the timeline.
    private var hudHeight: CGFloat {
        hasActiveProject ? 130 : 80
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // MARK: - Top Row: Task Info + Actions
            topInfoRow

            // MARK: - Middle Row: Project Timeline (only when project is active/paused)
            if hasActiveProject {
                projectTimelineRow
            }

            // MARK: - Bottom Row: Sub-Goal Progress
            subGoalRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 360, height: hudHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            configureMenuBarDashboardCallback()
        }
        .onChange(of: hasActiveProject) {
            // Resize and reposition the HUD panel when the timeline appears/disappears.
            if let hud = NSApp.windows.compactMap({ $0 as? HUDPanel }).first {
                hud.resize(height: hudHeight)
            }
        }
        .sheet(isPresented: $showingEditor, onDismiss: {
            // Bug fix: macOS may reposition the HUD panel when presenting/dismissing
            // a sheet. Re-anchor it to bottom-center after the sheet closes.
            if let hud = NSApp.windows.compactMap({ $0 as? HUDPanel }).first {
                hud.positionAtBottomCenter()
            }
        }) {
            MidTaskEditorView()
                .environmentObject(appState)
        }
    }

    // MARK: - Top Info Row

    /// Shows current project/task names on the left, elapsed time + action buttons on the right.
    private var topInfoRow: some View {
        HStack(spacing: 6) {
            // Left side: project + task labels
            if let task = appState.currentTask {
                VStack(alignment: .leading, spacing: 1) {
                    // Show project name if the task belongs to one.
                    if let project = appState.currentProject {
                        Text(project.name)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        if task.status == .paused {
                            Image(systemName: "pause.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 9))
                        }
                        Text(task.status == .paused ? "Paused: \(task.title)" : task.title)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(task.status == .paused ? .secondary : .primary)
                    }
                }

                Spacer()

                // Elapsed time
                Text(formatDuration(appState.elapsedTime))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)

                // Pause/Resume
                if task.status == .active {
                    Button(action: { appState.pauseTask() }) {
                        Image(systemName: "pause")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Pause")
                } else if task.status == .paused {
                    Button(action: { appState.resumeTask() }) {
                        Image(systemName: "play")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.green)
                    .help("Resume")
                }

                // Edit task
                Button(action: { showingEditor = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Edit Task")

            } else {
                Text("No active task")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Action icons (always visible)
            actionButtons
        }
    }

    // MARK: - Action Buttons

    /// Dashboard, Settings, and "+" create button (always visible on the right side).
    private var actionButtons: some View {
        HStack(spacing: 6) {
            Button(action: openDashboardWindow) {
                Image(systemName: "square.grid.2x2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open Dashboard")

            Button(action: openSettingsWindow) {
                Image(systemName: "gearshape.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")

            // "+" dropdown: create new task or project.
            // Grayed out when a project is active (user must pause project first).
            createButton
        }
    }

    /// The circular "+" button that opens a dropdown with "New Task" and "New Project" options.
    /// Disabled (grayed out) when a project is active — user must pause the project first.
    private var createButton: some View {
        let isProjectActive = appState.currentProject?.status == .active
        let isDisabled = isProjectActive || appState.currentTask != nil

        return Menu {
            Button("New Task") {
                appState.ankiGateTarget = .task
                appState.showingAnkiGate = true
            }
            Button("New Project") {
                appState.ankiGateTarget = .project
                appState.showingAnkiGate = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.caption.weight(.semibold))
                .foregroundColor(isDisabled ? .gray.opacity(0.4) : .accentColor)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(isDisabled ? Color.gray.opacity(0.1) : Color.accentColor.opacity(0.15))
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 20)
        .disabled(isDisabled)
        .help(isDisabled ? "Pause your current work to create something new" : "New Task or Project")
    }

    // MARK: - Project Timeline Row

    /// Displays the project's task sequence as proportionally-spaced circles with a calendar-time
    /// triangle marker. Only rendered when `showTimeline` is true (active/paused project).
    private var projectTimelineRow: some View {
        Group {
            if let project = appState.currentProject {
                ProjectTimelineView(
                    project: project,
                    currentTaskId: appState.currentTask?.id,
                    isDimmed: project.status == .paused
                )
            }
        }
    }

    // MARK: - Sub-Goal Row

    /// Shows sub-goal progress segments when a task has sub-goals,
    /// or "No projects" text when no project exists, or empty space otherwise.
    private var subGoalRow: some View {
        Group {
            if let task = appState.currentTask, !appState.subGoals.isEmpty {
                SubGoalProgressBar(
                    total: appState.subGoals.count,
                    completed: appState.completedSubGoalCount,
                    isPaused: task.status == .paused
                )
            } else if appState.currentProject == nil {
                Text("No projects")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Color.clear.frame(height: 6)
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Opens the Dashboard SwiftUI Scene window with proper focus handling.
    private func openDashboardWindow() {
        NSApp.activate()
        openWindow(id: "dashboard")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.activate()
            if let w = NSApp.windows.first(where: { $0.title == "Dashboard" }) {
                w.orderFrontRegardless()
                w.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// Opens the Settings SwiftUI Scene window with proper focus handling.
    private func openSettingsWindow() {
        NSApp.activate()
        openSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.activate()
            if let w = NSApp.windows.first(where: { $0.title == "Settings" }) {
                w.orderFrontRegardless()
                w.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// Passes the SwiftUI `openWindow` environment to the menu bar manager so its
    /// right-click "Open Dashboard" action can open the Dashboard Scene window.
    private func configureMenuBarDashboardCallback() {
        if let delegate = NSApp.delegate as? AppDelegate {
            let capturedOpenWindow = openWindow
            delegate.configureMenuBarCallbacks(openDashboard: {
                NSApp.activate()
                capturedOpenWindow(id: "dashboard")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NSApp.activate()
                    if let w = NSApp.windows.first(where: { $0.title == "Dashboard" }) {
                        w.orderFrontRegardless()
                        w.makeKeyAndOrderFront(nil)
                    }
                }
            })
        }
    }
}

// MARK: - Sub-Goal Progress Bar

/// A horizontal row of colored segments representing sub-goal completion.
/// Green = completed, gray = pending. Dimmed when the task is paused.
struct SubGoalProgressBar: View {
    let total: Int
    let completed: Int
    let isPaused: Bool

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(0..<total, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index < completed
                              ? (isPaused ? Color.green.opacity(0.5) : Color.green)
                              : Color.gray.opacity(0.3))
                        .frame(height: 6)
                }
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Project Timeline View

/// Visualizes a project's task sequence as circles on a horizontal timeline.
///
/// - Circles are proportionally spaced by each task's estimated duration.
/// - Circle states: hollow (pending), filled green (completed), filled red (abandoned),
///   highlighted ring (current task).
/// - A triangle marker shows the current calendar position between project start and end dates.
/// - The entire timeline dims when the project is paused.
struct ProjectTimelineView: View {
    let project: ProjectRecord
    let currentTaskId: UUID?
    let isDimmed: Bool

    /// Loaded on appear — the project's tasks in execution order.
    @State private var tasks: [TaskRecord] = []

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height: CGFloat = 24
            let circleRadius: CGFloat = 5
            let totalDuration = tasks.reduce(0.0) { $0 + $1.estimatedDuration }

            ZStack(alignment: .leading) {
                // Baseline
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.gray.opacity(isDimmed ? 0.1 : 0.25))
                    .frame(height: 2)
                    .offset(y: 0)

                // Task circles — proportionally positioned by cumulative duration.
                if totalDuration > 0 {
                    ForEach(tasks) { task in
                        let position = taskCenterX(task: task, totalDuration: totalDuration, width: width)

                        Circle()
                            .fill(circleFill(for: task))
                            .frame(width: circleRadius * 2, height: circleRadius * 2)
                            .overlay(
                                // Highlight ring for the current task.
                                Circle()
                                    .strokeBorder(Color.accentColor, lineWidth: task.id == currentTaskId ? 2 : 0)
                                    .frame(width: circleRadius * 2 + 4, height: circleRadius * 2 + 4)
                            )
                            .position(x: position, y: height / 2)
                    }

                    // Triangle marker at current calendar-time position.
                    triangleMarker(width: width, height: height)
                }
            }
            .frame(height: height)
        }
        .frame(height: 24)
        .opacity(isDimmed ? 0.4 : 1.0)
        .onAppear { loadTasks() }
    }

    /// Computes the center X position for a task circle based on cumulative duration.
    /// Tasks are placed at the midpoint of their duration segment on the timeline.
    private func taskCenterX(task: TaskRecord, totalDuration: TimeInterval, width: CGFloat) -> CGFloat {
        guard totalDuration > 0 else { return width / 2 }

        var cumulativeBefore: TimeInterval = 0
        for t in tasks {
            if t.id == task.id { break }
            cumulativeBefore += t.estimatedDuration
        }
        let midpoint = cumulativeBefore + task.estimatedDuration / 2
        // Inset slightly so circles don't clip at edges.
        let inset: CGFloat = 10
        let usableWidth = width - inset * 2
        return inset + usableWidth * CGFloat(midpoint / totalDuration)
    }

    /// Returns the fill color for a task's circle based on its status.
    private func circleFill(for task: TaskRecord) -> Color {
        switch task.status {
        case .completed:
            return .green
        case .abandoned:
            return .red
        case .active, .paused, .debriefing:
            return task.id == currentTaskId ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.3)
        case .planning:
            return Color.gray.opacity(0.3)
        }
    }

    /// A downward-pointing triangle showing the current date's position on the timeline.
    /// Position is based on calendar time: `(now - startDate) / (endDate - startDate)`.
    private func triangleMarker(width: CGFloat, height: CGFloat) -> some View {
        let totalSpan = project.endDate.timeIntervalSince(project.startDate)
        let elapsed = Date().timeIntervalSince(project.startDate)
        let fraction = totalSpan > 0 ? max(0, min(1, elapsed / totalSpan)) : 0

        let inset: CGFloat = 10
        let usableWidth = width - inset * 2
        let x = inset + usableWidth * CGFloat(fraction)

        return Triangle()
            .fill(Color.primary.opacity(0.6))
            .frame(width: 8, height: 6)
            .position(x: x, y: height / 2 - 10)
    }

    private func loadTasks() {
        tasks = (try? DatabaseManager.shared.fetchProjectTasks(forProject: project.id)) ?? []
    }
}

/// A simple downward-pointing triangle shape used as the calendar-time marker on the timeline.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
