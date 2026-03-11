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

    init(
        id: UUID = UUID(),
        title: String,
        justification: String,
        estimatedDuration: TimeInterval = 0,
        actualDuration: TimeInterval = 0,
        status: TaskStatus = .planning,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.justification = justification
        self.estimatedDuration = estimatedDuration
        self.actualDuration = actualDuration
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
