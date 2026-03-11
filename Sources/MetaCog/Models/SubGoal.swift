import Foundation
import GRDB

struct SubGoal: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "subGoal"

    var id: UUID
    var taskId: UUID
    var title: String
    var estimatedDuration: TimeInterval
    var order: Int
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        taskId: UUID,
        title: String,
        estimatedDuration: TimeInterval = 0,
        order: Int = 0,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.title = title
        self.estimatedDuration = estimatedDuration
        self.order = order
        self.completedAt = completedAt
    }

    var isCompleted: Bool { completedAt != nil }
}
