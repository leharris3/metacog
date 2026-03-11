import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var currentTask: TaskRecord?
    @Published var subGoals: [SubGoal] = []
    @Published var appPermissions: [AppPermission] = []
    @Published var hasInterruptedTask = false
    @Published var showingPlanningWizard = false
    @Published var showingDebrief = false
    @Published var showingDashboard = false
    @Published var interventionCount = 0

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
    }

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
