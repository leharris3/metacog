import SwiftUI

/// Dashboard page for viewing and managing projects.
///
/// **Layout:** Two-pane — project list on left, detail view on right.
///
/// **Left pane:** All projects sorted by creation date, showing name, date range,
/// status badge, and task completion ratio. Includes a "New Project" button.
///
/// **Right pane:** Selected project detail with metacognition responses, ordered task
/// list with statuses, and project debrief (if completed). Also includes an "Edit Project"
/// button for reordering/adding/removing tasks (only for active/paused projects).
struct ProjectsPageView: View {
    @EnvironmentObject private var appState: AppState

    @State private var projects: [ProjectRecord] = []
    @State private var selectedProjectId: UUID?
    @State private var showingEditProject = false

    var body: some View {
        HSplitView {
            // Left: project list
            projectListPane
                .frame(minWidth: 250, idealWidth: 300)

            // Right: project detail
            projectDetailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { reloadProjects() }
    }

    // MARK: - Left Pane: Project List

    private var projectListPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.headline)
                Spacer()
                Button(action: {
                    appState.ankiGateTarget = .project
                    appState.showingAnkiGate = true
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New Project")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if projects.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No projects yet")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(projects) { project in
                            projectRow(project)
                                .onTapGesture { selectedProjectId = project.id }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private func projectRow(_ project: ProjectRecord) -> some View {
        let isSelected = selectedProjectId == project.id
        let tasks = (try? DatabaseManager.shared.fetchProjectTasks(forProject: project.id)) ?? []
        let completedCount = tasks.filter { $0.status == .completed }.count

        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Date range
                    Text("\(project.startDate.formatted(date: .abbreviated, time: .omitted)) – \(project.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    // Status badge
                    Text(project.status.rawValue.capitalized)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(statusColor(project.status))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(statusColor(project.status).opacity(0.15))
                        )

                    // Task completion ratio
                    Text("\(completedCount)/\(tasks.count) tasks")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : .clear)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Right Pane: Project Detail

    @ViewBuilder
    private var projectDetailPane: some View {
        if let id = selectedProjectId,
           let project = projects.first(where: { $0.id == id }) {
            ProjectDetailView(
                project: project,
                onEdit: { showingEditProject = true },
                onReload: { reloadProjects() }
            )
            .id(id) // Force re-render when selection changes.
            .sheet(isPresented: $showingEditProject) {
                EditProjectView(project: project, onSave: { reloadProjects() })
                    .environmentObject(appState)
            }
        } else {
            VStack {
                Image(systemName: "folder")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("Select a project")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Helpers

    private func reloadProjects() {
        projects = (try? DatabaseManager.shared.fetchAllProjects()) ?? []
    }

    private func statusColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .planning: .blue
        case .active: .green
        case .paused: .orange
        case .debriefing: .purple
        case .completed: .green
        case .abandoned: .red
        }
    }
}

// MARK: - Project Detail View

/// Shows full detail for a selected project: metadata, metacognition responses,
/// task list with statuses, and debrief (if available).
struct ProjectDetailView: View {
    let project: ProjectRecord
    let onEdit: () -> Void
    let onReload: () -> Void

    @State private var tasks: [TaskRecord] = []
    @State private var debrief: ProjectDebrief?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.title2.weight(.bold))
                        Text("\(project.startDate.formatted(date: .abbreviated, time: .omitted)) – \(project.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Edit button — only for active/paused/planning projects.
                    if project.status == .active || project.status == .paused || project.status == .planning {
                        Button("Edit") { onEdit() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                // Metacognition responses
                VStack(alignment: .leading, spacing: 8) {
                    Text("Why Important")
                        .font(.headline)
                    Text(project.importanceResponse)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Anticipated Challenges")
                        .font(.headline)
                    Text(project.challengesResponse)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Task list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tasks")
                        .font(.headline)

                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(taskStatusColor(task.status)))

                            Text(task.title)
                                .font(.body)
                                .lineLimit(1)

                            Spacer()

                            Text(task.status.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(taskStatusColor(task.status))

                            if task.actualDuration > 0 {
                                Text(formatMinutes(task.actualDuration))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Debrief section
                if let debrief {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Debrief")
                            .font(.headline)

                        LabeledContent("Outcome", value: debrief.overallOutcome.rawValue.capitalized)
                        LabeledContent("Reflection", value: debrief.reflectionResponse)
                        LabeledContent("Goals", value: debrief.goalsReflectionResponse)
                    }
                }
            }
            .padding(20)
        }
        .onAppear { loadData() }
    }

    private func loadData() {
        tasks = (try? DatabaseManager.shared.fetchProjectTasks(forProject: project.id)) ?? []
        debrief = try? DatabaseManager.shared.fetchProjectDebrief(forProject: project.id)
    }

    private func taskStatusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .completed: .green
        case .abandoned: .red
        case .active: .blue
        case .paused: .orange
        case .planning: .gray
        case .debriefing: .purple
        }
    }

    private func formatMinutes(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        return "\(mins) min"
    }
}

// MARK: - Edit Project View

/// Sheet for editing a project's task list: add, delete, and reorder tasks.
/// Available from the project detail view on the dashboard.
struct EditProjectView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let project: ProjectRecord
    let onSave: () -> Void

    @State private var tasks: [TaskRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Project Tasks")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .padding(.top, 16)

            Text("Drag to reorder. Tasks are completed in sequence.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)
                                .font(.caption)

                            Text("\(index + 1). \(task.title)")
                                .font(.body)
                                .lineLimit(1)

                            Spacer()

                            Text(task.status.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            // Only allow deleting planning-status tasks.
                            if task.status == .planning {
                                Button(action: {
                                    try? DatabaseManager.shared.deleteTask(id: task.id)
                                    tasks.remove(at: index)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.background.opacity(0.5)))
                    }
                    .onMove(perform: moveTask)
                }
                .padding(16)
            }

            HStack {
                Spacer()
                Button("Save") {
                    saveOrder()
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 460, height: 400)
        .background(.ultraThinMaterial)
        .onAppear {
            tasks = (try? DatabaseManager.shared.fetchProjectTasks(forProject: project.id)) ?? []
        }
    }

    private func moveTask(from source: IndexSet, to destination: Int) {
        tasks.move(fromOffsets: source, toOffset: destination)
    }

    /// Persists the new task order by updating each task's `projectOrder` field.
    private func saveOrder() {
        for (index, var task) in tasks.enumerated() {
            task.projectOrder = index
            try? DatabaseManager.shared.updateTask(task)
        }
    }
}
