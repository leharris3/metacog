import Foundation
import GRDB

enum TaskStatus: String, Codable, DatabaseValueConvertible, CaseIterable, Sendable {
    case planning
    case active
    case paused
    case debriefing
    case completed
    case abandoned
}

struct TaskRecord: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "task"

    var id: UUID
    var title: String
    var justification: String
    var estimatedDuration: TimeInterval
    var actualDuration: TimeInterval
    var status: TaskStatus
    var createdAt: Date
    var completedAt: Date?

    /// The project this task belongs to, or `nil` for standalone tasks.
    /// Standalone tasks are subject to the 30-minute duration cap.
    var projectId: UUID?

    /// The execution order of this task within its project (0-indexed).
    /// Only meaningful when `projectId != nil`. Tasks must be completed in order.
    var projectOrder: Int?

    init(
        id: UUID = UUID(),
        title: String,
        justification: String,
        estimatedDuration: TimeInterval = 0,
        actualDuration: TimeInterval = 0,
        status: TaskStatus = .planning,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        projectId: UUID? = nil,
        projectOrder: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.justification = justification
        self.estimatedDuration = estimatedDuration
        self.actualDuration = actualDuration
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.projectId = projectId
        self.projectOrder = projectOrder
    }
}
