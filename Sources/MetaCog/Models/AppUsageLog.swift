import Foundation
import GRDB

/// Tracks per-app foreground time for analytics (not in original spec but needed for
/// Dashboard Page 2 detail view "Foreground time per application")
struct AppUsageLog: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "appUsageLog"

    var id: UUID
    var taskId: UUID
    var bundleIdentifier: String
    var appName: String
    var startTime: Date
    var duration: TimeInterval

    init(
        id: UUID = UUID(),
        taskId: UUID,
        bundleIdentifier: String,
        appName: String,
        startTime: Date = Date(),
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.taskId = taskId
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.startTime = startTime
        self.duration = duration
    }
}
