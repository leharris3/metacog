import SwiftUI

struct PlanningWizardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var taskTitle = ""
    @State private var justification = ""
    @State private var selectedApps: Set<String> = []  // bundle IDs
    @State private var installedApps: [InstalledApp] = []
    @State private var appGroups: [AppGroup] = []
    @State private var subGoals: [WizardSubGoal] = []
    @State private var estimatedDuration: TimeInterval = 0
    @State private var searchText = ""

    private let steps = [
        "Define Task",
        "Justify Importance",
        "Select Resources",
        "Group Linked Apps",
        "Set Sub-Goals",
        "Estimate Duration",
        "Confirm & Start"
    ]

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
                case 0: step1DefineTask
                case 1: step2Justify
                case 2: step3SelectResources
                case 3: step4GroupApps
                case 4: step5SubGoals
                case 5: step6EstimateDuration
                case 6: step7Confirm
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
                    appState.showingPlanningWizard = false
                    dismiss()
                }
                    .foregroundStyle(.secondary)
                if currentStep < steps.count - 1 {
                    Button("Next") { advanceStep() }
                        .keyboardShortcut(.return)
                        .disabled(!canAdvance)
                } else {
                    Button("Start Task") { createAndStartTask() }
                        .keyboardShortcut(.return)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .frame(width: 520, height: 480)
        .background(.ultraThinMaterial)
        .onAppear {
            installedApps = InstalledAppsService.fetchInstalledApps()
        }
    }

    // MARK: - Steps

    private var step1DefineTask: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What are you going to work on?")
                .foregroundStyle(.secondary)
            TextField("Task name", text: $taskTitle)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
        }
    }

    private var step2Justify: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why is this task important right now?")
                .foregroundStyle(.secondary)
            TextEditor(text: $justification)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
    }

    private var step3SelectResources: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which applications do you need?")
                .foregroundStyle(.secondary)

            TextField("Search apps…", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredApps) { app in
                        HStack(spacing: 8) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                            Toggle(app.name, isOn: Binding(
                                get: { selectedApps.contains(app.id) },
                                set: { isOn in
                                    if isOn { selectedApps.insert(app.id) }
                                    else { selectedApps.remove(app.id) }
                                }
                            ))
                            .toggleStyle(.checkbox)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var step4GroupApps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group apps that work together (switching within a group won't trigger interventions).")
                .foregroundStyle(.secondary)
                .font(.caption)

            HStack {
                Button(action: {
                    appGroups.append(AppGroup(name: "Group \(appGroups.count + 1)", appIds: []))
                }) {
                    Label("New Group", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                Spacer()
            }

            if appGroups.isEmpty && !selectedApps.isEmpty {
                Text("No groups created. All apps will trigger interventions when switching between them.")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                    .padding(.top, 20)
            }

            ScrollView {
                ForEach($appGroups) { $group in
                    GroupEditorRow(
                        group: $group,
                        availableApps: selectedAppObjects,
                        allGroups: appGroups,
                        onDelete: {
                            appGroups.removeAll { $0.id == group.id }
                        }
                    )
                }
            }
        }
    }

    private var step5SubGoals: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Break your task into sub-goals (optional).")
                .foregroundStyle(.secondary)

            HStack {
                Button(action: {
                    subGoals.append(WizardSubGoal(title: "", estimatedMinutes: 15))
                }) {
                    Label("Add Sub-Goal", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                Spacer()
            }

            ScrollView {
                ForEach(Array(subGoals.enumerated()), id: \.element.id) { index, _ in
                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        TextField("Sub-goal title", text: $subGoals[index].title)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 4) {
                            TextField("Min", value: $subGoals[index].estimatedMinutes, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            Text("min")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Button(action: { subGoals.remove(at: index) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var step6EstimateDuration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How long do you think this task will take?")
                .foregroundStyle(.secondary)

            let subGoalTotal = subGoals.reduce(0.0) { $0 + $1.estimatedMinutes }
            if subGoalTotal > 0 {
                Text("Sub-goal estimates total: \(Int(subGoalTotal)) minutes")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }

            HStack {
                TextField("Minutes", value: Binding(
                    get: { estimatedDuration / 60 },
                    set: { estimatedDuration = $0 * 60 }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                Text("minutes")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            let subGoalTotal = subGoals.reduce(0.0) { $0 + $1.estimatedMinutes } * 60
            if estimatedDuration == 0 && subGoalTotal > 0 {
                estimatedDuration = subGoalTotal
            }
        }
    }

    private var step7Confirm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LabeledContent("Task", value: taskTitle)
                LabeledContent("Justification", value: justification)
                LabeledContent("Apps", value: "\(selectedApps.count) selected")
                LabeledContent("Groups", value: "\(appGroups.count)")
                LabeledContent("Sub-Goals", value: "\(subGoals.count)")
                LabeledContent("Estimated Duration", value: "\(Int(estimatedDuration / 60)) minutes")
            }
            .font(.body)
        }
    }

    // MARK: - Helpers

    private var filteredApps: [InstalledApp] {
        if searchText.isEmpty { return installedApps }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedAppObjects: [InstalledApp] {
        installedApps.filter { selectedApps.contains($0.id) }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 0: return !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !justification.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func advanceStep() {
        guard canAdvance else { return }
        currentStep += 1
    }

    private func createAndStartTask() {
        let task = TaskRecord(
            title: taskTitle.trimmingCharacters(in: .whitespaces),
            justification: justification.trimmingCharacters(in: .whitespaces),
            estimatedDuration: estimatedDuration
        )

        try? DatabaseManager.shared.createTask(task)

        // Create app permissions
        for appId in selectedApps {
            if let app = installedApps.first(where: { $0.id == appId }) {
                // Find group for this app
                let groupId = appGroups.first(where: { $0.appIds.contains(appId) })?.id
                let perm = AppPermission(
                    taskId: task.id,
                    bundleIdentifier: appId,
                    appName: app.name,
                    linkedGroupId: groupId
                )
                try? DatabaseManager.shared.createAppPermission(perm)
            }
        }

        // Create sub-goals
        for (index, sg) in subGoals.enumerated() where !sg.title.trimmingCharacters(in: .whitespaces).isEmpty {
            let subGoal = SubGoal(
                taskId: task.id,
                title: sg.title.trimmingCharacters(in: .whitespaces),
                estimatedDuration: sg.estimatedMinutes * 60,
                order: index
            )
            try? DatabaseManager.shared.createSubGoal(subGoal)
        }

        appState.startTask(task)
        appState.showingPlanningWizard = false
        dismiss()
    }
}

// MARK: - Supporting Types

struct WizardSubGoal: Identifiable {
    let id = UUID()
    var title: String
    var estimatedMinutes: Double
}

struct AppGroup: Identifiable {
    let id = UUID()
    var name: String
    var appIds: Set<String>
}

struct GroupEditorRow: View {
    @Binding var group: AppGroup
    let availableApps: [InstalledApp]
    let allGroups: [AppGroup]
    let onDelete: () -> Void

    // Apps already assigned to other groups
    private var appsInOtherGroups: Set<String> {
        var ids = Set<String>()
        for g in allGroups where g.id != group.id {
            ids.formUnion(g.appIds)
        }
        return ids
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Group name", text: $group.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            FlowLayout(spacing: 4) {
                ForEach(availableApps.filter({ !appsInOtherGroups.contains($0.id) })) { app in
                    Toggle(isOn: Binding(
                        get: { group.appIds.contains(app.id) },
                        set: { isOn in
                            if isOn { group.appIds.insert(app.id) }
                            else { group.appIds.remove(app.id) }
                        }
                    )) {
                        HStack(spacing: 4) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 14, height: 14)
                            Text(app.name)
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.background.opacity(0.5)))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
