import Foundation
import GRDB

/// Lifecycle states for a project. Mirrors the task lifecycle but operates at a higher level.
///
/// ```
/// planning → active → [paused ↔ active] → debriefing → completed/abandoned
/// ```
///
/// - `planning`: Project created via the setup wizard but not yet started.
/// - `active`: User is actively working through the project's tasks (in sequential order).
/// - `paused`: User explicitly paused the project (e.g., to work on a standalone task).
/// - `debriefing`: All tasks finished or user abandoned — debrief wizard is showing.
/// - `completed`: Project debrief finalized with a non-failure outcome.
/// - `abandoned`: Project debrief finalized with a failure outcome.
enum ProjectStatus: String, Codable, DatabaseValueConvertible, CaseIterable, Sendable {
    case planning
    case active
    case paused
    case debriefing
    case completed
    case abandoned
}

/// A long-horizon effort composed of multiple sequential tasks.
///
/// Projects enforce:
/// - A minimum of 2 fully-configured tasks, worked in a set order.
/// - An end date that blocks new task creation when exceeded.
/// - Metacognition questions at setup and debrief for reflective planning.
///
/// Tasks belonging to a project are exempt from the 30-minute standalone task limit.
struct ProjectRecord: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "project"

    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var status: ProjectStatus
    var createdAt: Date
    var completedAt: Date?

    // MARK: - Metacognition Responses (Setup Wizard)

    /// Response to "Why is this project important?"
    var importanceResponse: String

    /// Response to "What challenges might you face? How do you plan to overcome them?"
    var challengesResponse: String

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        status: ProjectStatus = .planning,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        importanceResponse: String = "",
        challengesResponse: String = ""
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.importanceResponse = importanceResponse
        self.challengesResponse = challengesResponse
    }

    /// Whether the project has passed its deadline.
    /// When true, no new tasks can be created or started within this project.
    var isPastDeadline: Bool {
        Date() > endDate
    }
}

/// Stores reflective responses from the project debrief wizard.
///
/// Created when the user completes or abandons a project. Contains metacognition
/// reflections and a summary of all incomplete task titles for review.
struct ProjectDebrief: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "projectDebrief"

    var id: UUID
    var projectId: UUID
    var overallOutcome: DebriefOutcome
    /// Response to "What did you do well? What could you have done better?"
    var reflectionResponse: String
    /// Response to "Did you accomplish the goals you set at the outset? Why or why not?"
    var goalsReflectionResponse: String
    /// JSON-encoded list of incomplete task titles and the user's explanation for each.
    var incompleteTaskReflectionsJSON: String

    init(
        id: UUID = UUID(),
        projectId: UUID,
        overallOutcome: DebriefOutcome,
        reflectionResponse: String,
        goalsReflectionResponse: String,
        incompleteTaskReflectionsJSON: String = "[]"
    ) {
        self.id = id
        self.projectId = projectId
        self.overallOutcome = overallOutcome
        self.reflectionResponse = reflectionResponse
        self.goalsReflectionResponse = goalsReflectionResponse
        self.incompleteTaskReflectionsJSON = incompleteTaskReflectionsJSON
    }
}
