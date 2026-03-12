import SwiftUI

/// Multi-step wizard for creating a new project.
///
/// **Steps:**
/// 1. Project name, start date, and end date.
/// 2. Metacognition question: "Why is this project important?"
/// 3. Metacognition question: "What challenges might you face? How do you plan to overcome them?"
/// 4. Create tasks (minimum 2, fully configured via embedded task setup).
/// 5. Review and confirm.
///
/// On completion, the project is saved to the database and its first task becomes
/// available to start. Tasks are strictly sequential — users work through them in order.
///
/// This view is hosted in an NSWindow managed by `AppDelegate`, not as a SwiftUI sheet.
/// Dismissal is driven by setting `appState.showingProjectWizard = false`.
struct ProjectWizardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var currentStep = 0
    @State private var projectName = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
    @State private var importanceResponse = ""
    @State private var challengesResponse = ""
    @State private var projectTasks: [ProjectTaskDraft] = []

    // Embedded task editor state
    @State private var editingTaskIndex: Int? = nil
    @State private var showingTaskEditor = false

    private let steps = [
        "Project Details",
        "Why Important?",
        "Anticipate Challenges",
        "Create Tasks",
        "Review & Create"
    ]

    /// Minimum number of tasks required to create a project.
    private static let minimumTaskCount = 2

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            HStack(spacing: 4) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text(steps[currentStep])
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .padding(.top, 12)

            // Step content
            Group {
                switch currentStep {
                case 0: stepProjectDetails
                case 1: stepImportance
                case 2: stepChallenges
                case 3: stepCreateTasks
                case 4: stepReview
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") { currentStep -= 1 }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                }
                Spacer()
                Button("Cancel") {
                    appState.showingProjectWizard = false
                }
                .foregroundStyle(.secondary)
                if currentStep < steps.count - 1 {
                    Button("Next") { currentStep += 1 }
                        .keyboardShortcut(.return)
                        .disabled(!canAdvance)
                } else {
                    Button("Create Project") { createProject() }
                        .keyboardShortcut(.return)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAdvance)
                }
            }
            .padding(20)
        }
        .frame(width: 560, height: 600)
        .background(.ultraThinMaterial)
    }

    // MARK: - Step Views

    private var stepProjectDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What is this project about?")
                .foregroundStyle(.secondary)

            TextField("Project name", text: $projectName)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("End Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden()
                }
            }
        }
    }

    private var stepImportance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why is this project important?")
                .foregroundStyle(.secondary)
            Text("Articulating importance helps you stay motivated and prioritize effectively.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            TextEditor(text: $importanceResponse)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
    }

    private var stepChallenges: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What challenges might you face? How do you plan to overcome them?")
                .foregroundStyle(.secondary)
            Text("Anticipating obstacles improves your ability to handle them when they arise.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            TextEditor(text: $challengesResponse)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
    }

    private var stepCreateTasks: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add at least \(Self.minimumTaskCount) tasks (executed in order).")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: {
                    projectTasks.append(ProjectTaskDraft())
                    editingTaskIndex = projectTasks.count - 1
                    showingTaskEditor = true
                }) {
                    Label("Add Task", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if projectTasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No tasks yet. Click \"Add Task\" to get started.")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    ForEach(Array(projectTasks.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 8) {
                            // Order indicator
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color.accentColor))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title.isEmpty ? "Untitled Task" : task.title)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                Text("\(Int(task.estimatedDuration / 60)) min • \(task.selectedApps.count) apps • \(task.subGoals.count) sub-goals")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Edit button
                            Button(action: {
                                editingTaskIndex = index
                                showingTaskEditor = true
                            }) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)

                            // Delete button
                            Button(action: {
                                projectTasks.remove(at: index)
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red.opacity(0.7))
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.background.opacity(0.5)))
                    }
                }
            }

            if projectTasks.count < Self.minimumTaskCount {
                Text("You need at least \(Self.minimumTaskCount - projectTasks.count) more task\(projectTasks.count == Self.minimumTaskCount - 1 ? "" : "s").")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .sheet(isPresented: $showingTaskEditor) {
            if let index = editingTaskIndex {
                ProjectTaskEditorView(draft: $projectTasks[index])
            }
        }
    }

    private var stepReview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LabeledContent("Project", value: projectName)
                LabeledContent("Start Date", value: startDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("End Date", value: endDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Tasks", value: "\(projectTasks.count)")

                Divider()

                Text("Tasks (in order)")
                    .font(.headline)

                ForEach(Array(projectTasks.enumerated()), id: \.element.id) { index, task in
                    HStack {
                        Text("\(index + 1). \(task.title)")
                        Spacer()
                        Text("\(Int(task.estimatedDuration / 60)) min")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.body)
        }
    }

    // MARK: - Validation

    private var canAdvance: Bool {
        switch currentStep {
        case 0:
            return !projectName.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:
            return !importanceResponse.trimmingCharacters(in: .whitespaces).isEmpty
        case 2:
            return !challengesResponse.trimmingCharacters(in: .whitespaces).isEmpty
        case 3:
            // Need minimum tasks, each with a non-empty title.
            return projectTasks.count >= Self.minimumTaskCount
                && projectTasks.allSatisfy { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        case 4:
            return true
        default:
            return true
        }
    }

    // MARK: - Create Project

    private func createProject() {
        let project = ProjectRecord(
            name: projectName.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: endDate,
            status: .planning,
            importanceResponse: importanceResponse.trimmingCharacters(in: .whitespaces),
            challengesResponse: challengesResponse.trimmingCharacters(in: .whitespaces)
        )

        try? DatabaseManager.shared.createProject(project)

        // Create each task with a reference to this project and its order.
        for (index, draft) in projectTasks.enumerated() {
            let task = TaskRecord(
                title: draft.title.trimmingCharacters(in: .whitespaces),
                justification: draft.justification.trimmingCharacters(in: .whitespaces),
                estimatedDuration: draft.estimatedDuration,
                projectId: project.id,
                projectOrder: index
            )

            try? DatabaseManager.shared.createTask(task)

            // Create app permissions for this task.
            for appId in draft.selectedApps {
                if let app = draft.installedApps.first(where: { $0.id == appId }) {
                    let groupId = draft.appGroups.first(where: { $0.appIds.contains(appId) })?.id
                    let perm = AppPermission(
                        taskId: task.id,
                        bundleIdentifier: appId,
                        appName: app.name,
                        linkedGroupId: groupId
                    )
                    try? DatabaseManager.shared.createAppPermission(perm)
                }
            }

            // Create sub-goals for this task.
            for (sgIndex, sg) in draft.subGoals.enumerated()
                where !sg.title.trimmingCharacters(in: .whitespaces).isEmpty {
                let subGoal = SubGoal(
                    taskId: task.id,
                    title: sg.title.trimmingCharacters(in: .whitespaces),
                    estimatedDuration: sg.estimatedMinutes * 60,
                    order: sgIndex
                )
                try? DatabaseManager.shared.createSubGoal(subGoal)
            }
        }

        appState.currentProject = project
        appState.showingProjectWizard = false
    }
}

// MARK: - Draft Models

/// A temporary in-memory draft for a task being configured within the project wizard.
/// Converted to a `TaskRecord` + `AppPermission`s + `SubGoal`s when the project is created.
struct ProjectTaskDraft: Identifiable {
    let id = UUID()
    var title: String = ""
    var justification: String = ""
    var estimatedDuration: TimeInterval = 0
    var selectedApps: Set<String> = []
    var appGroups: [AppGroup] = []
    var subGoals: [WizardSubGoal] = []

    /// Cached installed apps list — populated when the task editor opens.
    var installedApps: [InstalledApp] = []
}

// MARK: - Project Task Editor

/// A sheet-based editor for configuring a single task within a project.
/// Reuses the same step concepts as `PlanningWizardView` but in a compact sheet form.
struct ProjectTaskEditorView: View {
    @Binding var draft: ProjectTaskDraft
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Configure Task")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Task Name")
                            .font(.headline)
                        TextField("What are you going to work on?", text: $draft.title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Justification
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Why is this task important?")
                            .font(.headline)
                        TextEditor(text: $draft.justification)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                            .frame(minHeight: 60, maxHeight: 100)
                    }

                    // Apps
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Permitted Apps")
                            .font(.headline)
                        TextField("Search apps…", text: $searchText)
                            .textFieldStyle(.roundedBorder)

                        let filtered = searchText.isEmpty
                            ? draft.installedApps
                            : draft.installedApps.filter {
                                $0.name.localizedCaseInsensitiveContains(searchText)
                            }

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(filtered) { app in
                                    HStack(spacing: 8) {
                                        Image(nsImage: app.icon)
                                            .resizable()
                                            .frame(width: 18, height: 18)
                                        Toggle(app.name, isOn: Binding(
                                            get: { draft.selectedApps.contains(app.id) },
                                            set: { isOn in
                                                if isOn { draft.selectedApps.insert(app.id) }
                                                else { draft.selectedApps.remove(app.id) }
                                            }
                                        ))
                                        .toggleStyle(.checkbox)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }

                    // Sub-Goals
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Sub-Goals")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                draft.subGoals.append(WizardSubGoal(title: "", estimatedMinutes: 15))
                            }) {
                                Label("Add", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        ForEach(Array(draft.subGoals.enumerated()), id: \.element.id) { index, _ in
                            HStack(spacing: 8) {
                                TextField("Sub-goal", text: $draft.subGoals[index].title)
                                    .textFieldStyle(.roundedBorder)
                                HStack(spacing: 4) {
                                    TextField("Min", value: $draft.subGoals[index].estimatedMinutes, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 50)
                                    Text("min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Button(action: { draft.subGoals.remove(at: index) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Duration
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Estimated Duration")
                            .font(.headline)
                        HStack {
                            TextField("Minutes", value: Binding(
                                get: { draft.estimatedDuration / 60 },
                                set: { draft.estimatedDuration = $0 * 60 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            Text("minutes")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }

            // Done button
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 480, height: 520)
        .background(.ultraThinMaterial)
        .onAppear {
            // Populate installed apps list on first open.
            if draft.installedApps.isEmpty {
                draft.installedApps = InstalledAppsService.fetchInstalledApps()
            }
        }
    }
}
