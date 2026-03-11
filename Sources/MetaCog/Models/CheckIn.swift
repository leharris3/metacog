import Foundation
import GRDB

struct CheckIn: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "checkIn"

    var id: UUID
    var subGoalId: UUID
    var timestamp: Date
    var isCompleted: Bool
    var reflection: String?
    var foregroundApp: String
    var elapsedTime: TimeInterval
    var amendmentsMade: String?

    init(
        id: UUID = UUID(),
        subGoalId: UUID,
        timestamp: Date = Date(),
        isCompleted: Bool,
        reflection: String? = nil,
        foregroundApp: String,
        elapsedTime: TimeInterval,
        amendmentsMade: String? = nil
    ) {
        self.id = id
        self.subGoalId = subGoalId
        self.timestamp = timestamp
        self.isCompleted = isCompleted
        self.reflection = reflection
        self.foregroundApp = foregroundApp
        self.elapsedTime = elapsedTime
        self.amendmentsMade = amendmentsMade
    }
}
