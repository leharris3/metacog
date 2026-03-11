import Foundation
import GRDB

struct DailyOverride: Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "dailyOverride"

    var date: String  // "yyyy-MM-dd" format, used as primary key
    var used: Int
    var limit: Int

    init(date: Date = Date(), used: Int = 0, limit: Int? = nil) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.date = formatter.string(from: date)
        self.used = used
        let stored = UserDefaults.standard.integer(forKey: "dailyOverrideLimit")
        self.limit = limit ?? (stored > 0 ? stored : 3)
    }

    var remainingOverrides: Int { max(0, limit - used) }
    var hasOverridesRemaining: Bool { used < limit }
}
