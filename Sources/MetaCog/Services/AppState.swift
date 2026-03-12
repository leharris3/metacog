import Foundation
import SwiftUI

/// Which wizard to open after the Anki gate challenge is passed.
enum AnkiGateTarget {
    case task
    case project
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var currentTask: TaskRecord?
    @Published var subGoals: [SubGoal] = []
    @Published var appPermissions: [AppPermission] = []
    @Published var hasInterruptedTask = false
    @Published var showingPlanningWizard = false
    @Published var showingProjectWizard = false
    @Published var showingDebrief = false
    @Published var showingDashboard = false
    @Published var interventionCount = 0

    // MARK: - Anki Gate

    /// When true, the Anki gate challenge window is visible.
    /// The user must answer a card correctly before the planning wizard opens.
    @Published var showingAnkiGate = false

    /// Determines which wizard opens after the Anki gate is passed.
    var ankiGateTarget: AnkiGateTarget = .task

    // MARK: - Project State

    /// The currently active or paused project, if any.
    @Published var currentProject: ProjectRecord?

    @Published var elapsedTime: TimeInterval = 0
    @Published var isTimerRunning = false

    private init() {}

    func loadTaskData() {
        guard let task = currentTask else {
            subGoals = []
            appPermissions = []
            return
        }
        subGoals = (try? DatabaseManager.shared.fetchSubGoals(forTask: task.id)) ?? []
        appPermissions = (try? DatabaseManager.shared.fetchAppPermissions(forTask: task.id)) ?? []
        elapsedTime = task.actualDuration
    }

    func startTask(_ task: TaskRecord) {
        var t = task
        t.status = .active
        try? DatabaseManager.shared.updateTask(t)
        currentTask = t
        interventionCount = 0
        loadTaskData()
        isTimerRunning = true

        // Start services
        TimeTracker.shared.startTracking()
        CheckInScheduler.shared.startMonitoring()
    }

    func pauseTask() {
        guard var task = currentTask, task.status == .active else { return }
        task.status = .paused
        task.actualDuration = elapsedTime
        try? DatabaseManager.shared.updateTask(task)
        currentTask = task
        isTimerRunning = false

        TimeTracker.shared.pauseTracking()
    }

    func resumeTask() {
        guard var task = currentTask, task.status == .paused else { return }
        task.status = .active
        try? DatabaseManager.shared.updateTask(task)
        currentTask = task
        isTimerRunning = true

        TimeTracker.shared.startTracking()
        CheckInScheduler.shared.startMonitoring()
    }

    func completeTask() {
        guard var task = currentTask else { return }
        task.status = .debriefing
        task.actualDuration = elapsedTime
        try? DatabaseManager.shared.updateTask(task)
        currentTask = task
        isTimerRunning = false
        showingDebrief = true

        TimeTracker.shared.stopTracking()
        CheckInScheduler.shared.stopMonitoring()
    }

    func abandonTask() {
        guard var task = currentTask else { return }
        task.status = .debriefing
        task.actualDuration = elapsedTime
        try? DatabaseManager.shared.updateTask(task)
        currentTask = task
        isTimerRunning = false
        showingDebrief = true

        TimeTracker.shared.stopTracking()
        CheckInScheduler.shared.stopMonitoring()
    }

    func finalizeDebrief(outcome: DebriefOutcome) {
        guard var task = currentTask else { return }
        task.status = outcome == .failure ? .abandoned : .completed
        task.completedAt = Date()
        task.actualDuration = elapsedTime
        try? DatabaseManager.shared.updateTask(task)
        currentTask = nil
        subGoals = []
        appPermissions = []
        elapsedTime = 0
        showingDebrief = false
        hasInterruptedTask = false

        // If this task belongs to a project, check if all project tasks are now done.
        // If so, auto-trigger the project debrief.
        if let project = currentProject, task.projectId == project.id {
            checkProjectCompletion(project)
        }
    }

    // MARK: - Project Lifecycle

    /// Activates a project and loads its first incomplete task for execution.
    /// Called after creating a project or resuming a paused one.
    func startProject(_ project: ProjectRecord) {
        var p = project
        p.status = .active
        try? DatabaseManager.shared.updateProject(p)
        currentProject = p
    }

    /// Explicitly pauses the current project, allowing the user to work on standalone tasks.
    /// Does NOT pause the current task — the user should finish or pause the task first.
    func pauseProject() {
        guard var project = currentProject, project.status == .active else { return }
        project.status = .paused
        try? DatabaseManager.shared.updateProject(project)
        currentProject = project
    }

    /// Resumes a previously paused project.
    func resumeProject() {
        guard var project = currentProject, project.status == .paused else { return }
        project.status = .active
        try? DatabaseManager.shared.updateProject(project)
        currentProject = project
    }

    /// Abandons the current project, triggering the project debrief wizard.
    func abandonProject() {
        guard var project = currentProject else { return }
        project.status = .debriefing
        try? DatabaseManager.shared.updateProject(project)
        currentProject = project
        showingProjectDebrief = true
    }

    /// Checks whether all tasks in a project are completed or abandoned.
    /// If so, transitions the project to debriefing and shows the project debrief wizard.
    private func checkProjectCompletion(_ project: ProjectRecord) {
        let tasks = (try? DatabaseManager.shared.fetchProjectTasks(forProject: project.id)) ?? []
        let allDone = tasks.allSatisfy { $0.status == .completed || $0.status == .abandoned }

        if allDone {
            var p = project
            p.status = .debriefing
            try? DatabaseManager.shared.updateProject(p)
            currentProject = p
            showingProjectDebrief = true
        }
    }

    /// Starts the next incomplete task in the current project's sequence.
    /// Returns the task if one was started, or nil if all tasks are done.
    @discardableResult
    func startNextProjectTask() -> TaskRecord? {
        guard let project = currentProject else { return nil }
        let tasks = (try? DatabaseManager.shared.fetchProjectTasks(forProject: project.id)) ?? []

        // Find the first task that hasn't been completed or abandoned.
        guard let nextTask = tasks.first(where: { $0.status == .planning }) else {
            return nil
        }

        startTask(nextTask)
        return nextTask
    }

    /// Finalizes the project debrief and sets the project's final status.
    func finalizeProjectDebrief(outcome: DebriefOutcome) {
        guard var project = currentProject else { return }
        project.status = outcome == .failure ? .abandoned : .completed
        project.completedAt = Date()
        try? DatabaseManager.shared.updateProject(project)
        currentProject = nil
        showingProjectDebrief = false
    }

    /// When true, the project debrief wizard window is visible.
    @Published var showingProjectDebrief = false

    func completeSubGoal(_ goal: SubGoal) {
        guard let index = subGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        var updated = goal
        updated.completedAt = Date()
        try? DatabaseManager.shared.updateSubGoal(updated)
        subGoals[index] = updated
    }

    var completedSubGoalCount: Int {
        subGoals.filter(\.isCompleted).count
    }

    var currentPenaltyDuration: TimeInterval {
        let base = UserDefaults.standard.double(forKey: "basePenaltySeconds")
        return (base > 0 ? base : 15.0) * pow(2.0, Double(interventionCount))
    }
}
