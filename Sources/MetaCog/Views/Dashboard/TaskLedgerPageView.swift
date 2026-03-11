import SwiftUI

struct TaskLedgerPageView: View {
    @State private var tasks: [TaskRecord] = []
    @State private var selectedTask: TaskRecord?

    var body: some View {
        HStack(spacing: 0) {
            List(completedTasks, selection: Binding(
                get: { selectedTask?.id },
                set: { id in selectedTask = tasks.first { $0.id == id } }
            )) { task in
                TaskLedgerRow(task: task)
                    .tag(task.id)
            }
            .frame(width: 350)

            Divider()

            Group {
                if let task = selectedTask {
                    TaskDetailView(task: task)
                        .id(task.id)
                } else {
                    ContentUnavailableView(
                        "Select a Task",
                        systemImage: "doc.text",
                        description: Text("Choose a task to view its details.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            tasks = (try? DatabaseManager.shared.fetchAllTasks()) ?? []
        }
    }

    private var completedTasks: [TaskRecord] {
        tasks.filter { $0.status == .completed || $0.status == .abandoned }
    }
}

struct TaskLedgerRow: View {
    let task: TaskRecord

    private var subGoalInfo: String {
        let goals = (try? DatabaseManager.shared.fetchSubGoals(forTask: task.id)) ?? []
        guard !goals.isEmpty else { return "" }
        let completed = goals.filter(\.isCompleted).count
        return "\(completed)/\(goals.count)"
    }

    private var debriefOutcome: DebriefOutcome? {
        (try? DatabaseManager.shared.fetchDebrief(forTask: task.id))?.overallOutcome
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if let outcome = debriefOutcome {
                    Text(outcome.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(outcomeColor(outcome).opacity(0.15))
                        .foregroundStyle(outcomeColor(outcome))
                        .clipShape(Capsule())
                }
            }
            HStack {
                if let date = task.completedAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !subGoalInfo.isEmpty {
                    Text(subGoalInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(formatDuration(task.actualDuration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func outcomeColor(_ outcome: DebriefOutcome) -> Color {
        switch outcome {
        case .success: .green
        case .partial: .orange
        case .failure: .red
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

struct TaskDetailView: View {
    let task: TaskRecord
    @State private var subGoals: [SubGoal] = []
    @State private var debrief: TaskDebrief?
    @State private var checkIns: [UUID: [CheckIn]] = [:]
    @State private var appUsage: [AppUsageLog] = []
    @State private var interventions: [Intervention] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.title2.weight(.bold))
                            if let date = task.completedAt {
                                Text(date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let outcome = debrief?.overallOutcome {
                            outcomeTag(outcome)
                        }
                    }
                    if !task.justification.isEmpty {
                        Text(task.justification)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Stats row
                HStack(spacing: 0) {
                    statCell(label: "Estimated", value: formatDuration(task.estimatedDuration), color: .primary)
                    Divider().frame(height: 36)
                    statCell(
                        label: "Actual",
                        value: formatDuration(task.actualDuration),
                        color: task.actualDuration > task.estimatedDuration ? .red : .green
                    )
                    if !interventions.isEmpty {
                        Divider().frame(height: 36)
                        statCell(label: "Interventions", value: "\(interventions.count)", color: .orange)
                    }
                }
                .padding(.vertical, 10)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Sub-goals
                if !subGoals.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(subGoals.enumerated()), id: \.element.id) { index, goal in
                                if index > 0 { Divider() }
                                subGoalRow(goal)
                            }
                        }
                    } label: {
                        Label(
                            "Sub-Goals (\(subGoals.filter(\.isCompleted).count)/\(subGoals.count))",
                            systemImage: "checklist"
                        )
                        .font(.subheadline.weight(.semibold))
                    }
                }

                // App usage
                if !appUsage.isEmpty {
                    let grouped = Dictionary(grouping: appUsage) { $0.appName }
                    let totals = grouped.mapValues { $0.reduce(0.0) { $0 + $1.duration } }
                        .sorted { $0.value > $1.value }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(totals, id: \.key) { app, duration in
                                HStack {
                                    Text(app).font(.callout)
                                    Spacer()
                                    Text(formatDuration(duration))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } label: {
                        Label("App Usage", systemImage: "macwindow")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                // Debrief
                if let debrief {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            if !debrief.subGoalReflections.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(debrief.subGoalReflections, id: \.subGoalId) { ref in
                                        let title = subGoals.first(where: { $0.id == ref.subGoalId })?.title ?? ""
                                        HStack(alignment: .top, spacing: 6) {
                                            Image(systemName: ref.wasCompleted
                                                  ? "checkmark.circle.fill"
                                                  : "xmark.circle.fill")
                                                .foregroundStyle(ref.wasCompleted ? .green : .red)
                                                .font(.caption)
                                                .padding(.top, 2)
                                            VStack(alignment: .leading, spacing: 2) {
                                                if !title.isEmpty {
                                                    Text(title)
                                                        .font(.callout)
                                                }
                                                if !ref.explanation.isEmpty {
                                                    Text(ref.explanation)
                                                        .font(.callout)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            if !debrief.lessonsLearned.isEmpty {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Lessons Learned")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                    Text(debrief.lessonsLearned)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } label: {
                        Label("Debrief", systemImage: "doc.text")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .padding(20)
        }
        .onAppear(perform: loadData)
    }

    @ViewBuilder
    private func subGoalRow(_ goal: SubGoal) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(goal.isCompleted ? Color.green : Color.secondary)
                Text(goal.title)
                    .font(.callout.weight(.medium))
                Spacer()
                Text(formatDuration(goal.estimatedDuration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            if let goalCheckIns = checkIns[goal.id], !goalCheckIns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(goalCheckIns) { ci in
                        checkInRow(ci)
                    }
                }
                .padding(.leading, 22)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private func checkInRow(_ ci: CheckIn) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(ci.timestamp, style: .time)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 38, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(appShortName(ci.foregroundApp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let reflection = ci.reflection, !reflection.isEmpty {
                    Text(reflection)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.75))
                }
                if let amendments = ci.amendmentsMade, !amendments.isEmpty {
                    Text("Amended: \(amendments)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func outcomeTag(_ outcome: DebriefOutcome) -> some View {
        let color = outcomeColor(outcome)
        return Text(outcome.rawValue.capitalized)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func outcomeColor(_ outcome: DebriefOutcome) -> Color {
        switch outcome {
        case .success: .green
        case .partial: .orange
        case .failure: .red
        }
    }

    private func appShortName(_ bundleId: String) -> String {
        bundleId.split(separator: ".").last.map(String.init) ?? bundleId
    }

    private func loadData() {
        let db = DatabaseManager.shared
        subGoals = (try? db.fetchSubGoals(forTask: task.id)) ?? []
        debrief = try? db.fetchDebrief(forTask: task.id)
        appUsage = (try? db.fetchAppUsageLogs(forTask: task.id)) ?? []
        interventions = (try? db.fetchInterventions(forTask: task.id)) ?? []
        for goal in subGoals {
            checkIns[goal.id] = (try? db.fetchCheckIns(forSubGoal: goal.id)) ?? []
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
