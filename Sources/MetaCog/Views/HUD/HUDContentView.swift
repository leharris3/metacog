import SwiftUI

struct HUDContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row
            HStack(spacing: 6) {
                if let task = appState.currentTask {
                    if task.status == .paused {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    Text(task.status == .paused ? "Paused: \(task.title)" : task.title)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(task.status == .paused ? .secondary : .primary)

                    Spacer()

                    Text(formatDuration(appState.elapsedTime))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)

                    // Quick actions
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

                // Dashboard + Settings buttons
                VStack(spacing: 2) {
                    Button(action: {
                        NSApp.activate()
                        openWindow(id: "dashboard")
                        // The HUD is a .nonactivatingPanel so clicking it doesn't
                        // activate MetaCog. Use a short delay for the SwiftUI scene
                        // to create the window, then force it to the front with
                        // orderFrontRegardless() which works even when the app
                        // isn't fully active yet.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            NSApp.activate()
                            if let w = NSApp.windows.first(where: { $0.title == "Dashboard" }) {
                                w.orderFrontRegardless()
                                w.makeKeyAndOrderFront(nil)
                            }
                        }
                    }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open Dashboard")

                    Button(action: {
                        NSApp.activate()
                        openSettings()
                        // Same delayed focus pattern as Dashboard above.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            NSApp.activate()
                            if let w = NSApp.windows.first(where: { $0.title == "Settings" }) {
                                w.orderFrontRegardless()
                                w.makeKeyAndOrderFront(nil)
                            }
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
            }

            // Bottom row: progress bar or new task button
            if let task = appState.currentTask {
                if !appState.subGoals.isEmpty {
                    SubGoalProgressBar(
                        total: appState.subGoals.count,
                        completed: appState.completedSubGoalCount,
                        isPaused: task.status == .paused
                    )
                }
            } else {
                Button(action: {
                    appState.showingPlanningWizard = true
                }) {
                    Label("New Task", systemImage: "plus")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 360, height: 80)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .sheet(isPresented: $showingEditor) {
            MidTaskEditorView()
                .environmentObject(appState)
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

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
