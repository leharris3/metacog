import Foundation
import GRDB

enum InterventionType: String, Codable, DatabaseValueConvertible, Sendable {
    case timer
    case anki
}

struct Intervention: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "intervention"

    var id: UUID
    var taskId: UUID
    var timestamp: Date
    var type: InterventionType
    var penaltyDuration: TimeInterval
    var ankiCardId: UUID?
    var wasCorrect: Bool?
    var wasOverridden: Bool

    init(
        id: UUID = UUID(),
        taskId: UUID,
        timestamp: Date = Date(),
        type: InterventionType,
        penaltyDuration: TimeInterval,
        ankiCardId: UUID? = nil,
        wasCorrect: Bool? = nil,
        wasOverridden: Bool = false
    ) {
        self.id = id
        self.taskId = taskId
        self.timestamp = timestamp
        self.type = type
        self.penaltyDuration = penaltyDuration
        self.ankiCardId = ankiCardId
        self.wasCorrect = wasCorrect
        self.wasOverridden = wasOverridden
    }
}
