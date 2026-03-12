import SwiftUI

/// Debrief wizard shown when a project's tasks are all complete/abandoned, or when the
/// user manually abandons the project.
///
/// **Steps:**
/// 1. Overall outcome picker (success / partial / failure).
/// 2. "What did you do well? What could you have done better?"
/// 3. "Did you accomplish the goals you set at the outset? Why or why not?"
/// 4. Review of all incomplete/abandoned tasks with per-task reflections.
/// 5. Submit.
///
/// On submit, a `ProjectDebrief` record is saved and the project is finalized via
/// `appState.finalizeProjectDebrief()`. The window closes when
/// `appState.showingProjectDebrief` is set to false.
struct ProjectDebriefView: View {
    @EnvironmentObject private var appState: AppState

    @State private var overallOutcome: DebriefOutcome = .partial
    @State private var reflectionResponse = ""
    @State private var goalsReflectionResponse = ""
    @State private var incompleteTaskReflections: [IncompleteTaskEntry] = []
    @State private var projectTasks: [TaskRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            Text("Project Debrief")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .padding(.top, 16)

            if let project = appState.currentProject {
                Text(project.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Outcome picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overall Outcome")
                            .font(.headline)
                        Picker("Outcome", selection: $overallOutcome) {
                            Text("Success").tag(DebriefOutcome.success)
                            Text("Partial").tag(DebriefOutcome.partial)
                            Text("Failure").tag(DebriefOutcome.failure)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Reflection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What did you do well? What could you have done better?")
                            .font(.headline)
                        TextEditor(text: $reflectionResponse)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                            .frame(minHeight: 80)
                    }

                    // Goals reflection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Did you accomplish the goals you set at the outset? Why or why not?")
                            .font(.headline)
                        TextEditor(text: $goalsReflectionResponse)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                            .frame(minHeight: 80)
                    }

                    // Incomplete task reflections
                    if !incompleteTaskReflections.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Incomplete Tasks")
                                .font(.headline)
                            Text("Reflect on why these tasks were not completed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach($incompleteTaskReflections) { $entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: entry.wasAbandoned ? "xmark.circle.fill" : "circle")
                                            .foregroundStyle(entry.wasAbandoned ? .red : .orange)
                                            .font(.caption)
                                        Text(entry.title)
                                            .font(.body.weight(.medium))
                                    }
                                    TextField("What happened?", text: $entry.explanation)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.callout)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.background.opacity(0.5)))
                            }
                        }
                    }
                }
                .padding(20)
            }

            // Submit
            HStack {
                Spacer()
                Button("Submit") {
                    saveDebrief()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(reflectionResponse.trimmingCharacters(in: .whitespaces).isEmpty
                          || goalsReflectionResponse.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 520, height: 560)
        .background(.ultraThinMaterial)
        .onAppear {
            loadProjectTasks()
        }
    }

    // MARK: - Data Loading

    private func loadProjectTasks() {
        guard let project = appState.currentProject else { return }
        projectTasks = (try? DatabaseManager.shared.fetchProjectTasks(forProject: project.id)) ?? []

        // Build entries for tasks that are incomplete (not .completed).
        incompleteTaskReflections = projectTasks
            .filter { $0.status != .completed }
            .map { task in
                IncompleteTaskEntry(
                    taskId: task.id,
                    title: task.title,
                    wasAbandoned: task.status == .abandoned,
                    explanation: ""
                )
            }
    }

    // MARK: - Save

    private func saveDebrief() {
        guard let project = appState.currentProject else { return }

        // Encode incomplete task reflections as JSON.
        let encoder = JSONEncoder()
        let reflectionsJSON = (try? encoder.encode(incompleteTaskReflections)) ?? Data()
        let reflectionsString = String(data: reflectionsJSON, encoding: .utf8) ?? "[]"

        let debrief = ProjectDebrief(
            projectId: project.id,
            overallOutcome: overallOutcome,
            reflectionResponse: reflectionResponse.trimmingCharacters(in: .whitespaces),
            goalsReflectionResponse: goalsReflectionResponse.trimmingCharacters(in: .whitespaces),
            incompleteTaskReflectionsJSON: reflectionsString
        )

        try? DatabaseManager.shared.createProjectDebrief(debrief)
        appState.finalizeProjectDebrief(outcome: overallOutcome)
    }
}

// MARK: - Supporting Types

/// A temporary UI model for reflecting on an incomplete project task.
struct IncompleteTaskEntry: Identifiable, Codable {
    var id: UUID { taskId }
    let taskId: UUID
    let title: String
    let wasAbandoned: Bool
    var explanation: String
}
