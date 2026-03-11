import Foundation
import GRDB

struct AppPermission: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "appPermission"

    var id: UUID
    var taskId: UUID
    var bundleIdentifier: String
    var appName: String
    var linkedGroupId: UUID?

    init(
        id: UUID = UUID(),
        taskId: UUID,
        bundleIdentifier: String,
        appName: String,
        linkedGroupId: UUID? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.linkedGroupId = linkedGroupId
    }
}
