import SwiftUI

struct MidTaskEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var newSubGoalTitle = ""
    @State private var newSubGoalMinutes: Double = 15
    @State private var removalJustification = ""
    @State private var goalToRemove: SubGoal?
    @State private var showingRemovalAlert = false

    // App request
    @State private var showingAppRequest = false
    @State private var appSearchText = ""
    @State private var appJustification = ""
    @State private var installedApps: [InstalledApp] = []

    var body: some View {
        NavigationStack {
            Form {
                // Task controls
                Section("Task") {
                    if let task = appState.currentTask {
                        LabeledContent("Status", value: task.status.rawValue.capitalized)

                        if task.status == .active {
                            Button("Pause Task") { appState.pauseTask() }
                        } else if task.status == .paused {
                            Button("Resume Task") { appState.resumeTask() }
                        }

                        Button("Complete Task") {
                            appState.completeTask()
                            dismiss()
                        }

                        Button("Abandon Task", role: .destructive) {
                            appState.abandonTask()
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }

                // Sub-goals
                Section("Sub-Goals") {
                    ForEach(appState.subGoals) { goal in
                        HStack {
                            Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(goal.isCompleted ? .green : .secondary)
                            Text(goal.title)
                                .lineLimit(2)
                            Spacer()
                            if !goal.isCompleted {
                                Button(action: { appState.completeSubGoal(goal) }) {
                                    Image(systemName: "checkmark")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button(action: {
                                    goalToRemove = goal
                                    showingRemovalAlert = true
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        TextField("New sub-goal", text: $newSubGoalTitle)
                        TextField("", value: $newSubGoalMinutes, format: .number)
                            .frame(width: 44)
                            .multilineTextAlignment(.trailing)
                        Text("min")
                            .foregroundStyle(.secondary)
                        Button("Add") { addSubGoal() }
                            .disabled(newSubGoalTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // Apps
                Section("Permitted Apps") {
                    ForEach(appState.appPermissions) { perm in
                        Text(perm.appName)
                    }
                    Button("Request Additional App") {
                        installedApps = InstalledAppsService.fetchInstalledApps()
                        showingAppRequest = true
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .frame(width: 480, height: 520)
        }
        .alert("Remove Sub-Goal", isPresented: $showingRemovalAlert) {
            TextField("Why are you removing this?", text: $removalJustification)
            Button("Cancel", role: .cancel) {
                goalToRemove = nil
                removalJustification = ""
            }
            Button("Remove", role: .destructive) {
                if let goal = goalToRemove {
                    try? DatabaseManager.shared.deleteSubGoal(id: goal.id)
                    appState.subGoals.removeAll { $0.id == goal.id }
                }
                goalToRemove = nil
                removalJustification = ""
            }
        }
        .sheet(isPresented: $showingAppRequest) {
            AppRequestSheet(
                installedApps: installedApps,
                existingPermissions: appState.appPermissions,
                onAdd: { app, justification in
                    guard let task = appState.currentTask else { return }
                    let perm = AppPermission(
                        taskId: task.id,
                        bundleIdentifier: app.id,
                        appName: app.name
                    )
                    try? DatabaseManager.shared.createAppPermission(perm)
                    appState.appPermissions.append(perm)
                }
            )
        }
    }

    private func addSubGoal() {
        guard let task = appState.currentTask,
              !newSubGoalTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let goal = SubGoal(
            taskId: task.id,
            title: newSubGoalTitle.trimmingCharacters(in: .whitespaces),
            estimatedDuration: newSubGoalMinutes * 60,
            order: appState.subGoals.count
        )
        try? DatabaseManager.shared.createSubGoal(goal)
        appState.subGoals.append(goal)
        newSubGoalTitle = ""
        newSubGoalMinutes = 15
    }
}

struct AppRequestSheet: View {
    let installedApps: [InstalledApp]
    let existingPermissions: [AppPermission]
    let onAdd: (InstalledApp, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedApp: InstalledApp?
    @State private var justification = ""

    private var existingBundleIds: Set<String> {
        Set(existingPermissions.map(\.bundleIdentifier))
    }

    private var filteredApps: [InstalledApp] {
        let available = installedApps.filter { !existingBundleIds.contains($0.id) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Request Additional App")
                .font(.headline)

            TextField("Search…", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(filteredApps) { app in
                        HStack {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(app.name)
                            Spacer()
                            if selectedApp?.id == app.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedApp = app }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(height: 200)

            if selectedApp != nil {
                TextField("Why do you need this app?", text: $justification)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    if let app = selectedApp {
                        onAdd(app, justification)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedApp == nil || justification.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400, height: 400)
    }
}
