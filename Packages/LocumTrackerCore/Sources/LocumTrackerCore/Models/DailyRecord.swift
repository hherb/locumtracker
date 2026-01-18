import Foundation
import SwiftData

/// Container for daily work sessions and earnings
@Model
public final class DailyRecord {
    public var id: UUID = UUID()
    public var assignmentId: UUID = UUID()
    public var date: Date = Date()
    public var totalEarnings: Double = 0
    public var subsidyEarnings: Double?
    public var notes: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        assignmentId: UUID,
        date: Date,
        notes: String? = nil
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.date = date
        self.totalEarnings = 0
        self.subsidyEarnings = nil
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// Represents an applied rate for transparency in invoicing
public struct AppliedRate: Codable, Sendable {
    public var sessionType: String
    public var rate: Double
    public var hours: Double
    public var amount: Double
    public var subsidyAmount: Double?

    public init(
        sessionType: String,
        rate: Double,
        hours: Double,
        amount: Double,
        subsidyAmount: Double? = nil
    ) {
        self.sessionType = sessionType
        self.rate = rate
        self.hours = hours
        self.amount = amount
        self.subsidyAmount = subsidyAmount
    }
}
