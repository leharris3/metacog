import Foundation
import GRDB

enum DebriefOutcome: String, Codable, DatabaseValueConvertible, CaseIterable, Sendable {
    case success
    case partial
    case failure
}

struct SubGoalReflection: Codable, Sendable {
    var subGoalId: UUID
    var wasCompleted: Bool
    var explanation: String
}

struct TaskDebrief: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "taskDebrief"

    var id: UUID
    var taskId: UUID
    var overallOutcome: DebriefOutcome
    var subGoalReflectionsJSON: String
    var lessonsLearned: String

    init(
        id: UUID = UUID(),
        taskId: UUID,
        overallOutcome: DebriefOutcome,
        subGoalReflections: [SubGoalReflection],
        lessonsLearned: String
    ) {
        self.id = id
        self.taskId = taskId
        self.overallOutcome = overallOutcome
        self.subGoalReflectionsJSON = (try? JSONEncoder().encode(subGoalReflections))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.lessonsLearned = lessonsLearned
    }

    var subGoalReflections: [SubGoalReflection] {
        guard let data = subGoalReflectionsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([SubGoalReflection].self, from: data)) ?? []
    }
}
