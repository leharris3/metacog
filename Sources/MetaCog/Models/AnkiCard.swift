import Foundation
import GRDB

struct AnkiCard: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "ankiCard"

    var id: UUID
    var front: String
    var back: String
    var easeFactor: Double
    var interval: Int
    var repetitions: Int
    var nextReviewDate: Date

    init(
        id: UUID = UUID(),
        front: String,
        back: String,
        easeFactor: Double = 2.5,
        interval: Int = 0,
        repetitions: Int = 0,
        nextReviewDate: Date = Date()
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
    }

    /// SM-2 algorithm: update card after review
    /// - Parameter quality: 0-5 rating (0-2 = incorrect, 3-5 = correct)
    mutating func review(quality: Int) {
        let q = Double(min(max(quality, 0), 5))

        // Update ease factor
        let newEF = easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        easeFactor = max(1.3, newEF)

        if quality >= 3 {
            // Correct
            switch repetitions {
            case 0: interval = 1
            case 1: interval = 6
            default: interval = Int(Double(interval) * easeFactor)
            }
            repetitions += 1
        } else {
            // Incorrect
            repetitions = 0
            interval = 1
        }

        nextReviewDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
    }

    var isDueForReview: Bool {
        nextReviewDate <= Date()
    }
}
