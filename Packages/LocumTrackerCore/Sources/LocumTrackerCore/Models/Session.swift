import Foundation
import SwiftData

/// Types of work sessions
public enum SessionType: String, CaseIterable, Codable {
    case regular = "regular"
    case onCall = "on_call"
    case callOut = "call_out"

    public var description: String {
        switch self {
        case .regular: return "Regular"
        case .onCall: return "On-Call"
        case .callOut: return "Call-Out"
        }
    }
}

/// Represents a work session within a daily record
@Model
public final class Session {
    public var id: UUID
    public var dailyRecordId: UUID
    public var startTime: Date
    public var endTime: Date
    public var sessionType: SessionType
    public var mmmClassification: Int
    public var travelTime: TimeInterval?
    public var subsidyAmount: Double?
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        dailyRecordId: UUID,
        startTime: Date,
        endTime: Date,
        sessionType: SessionType = .regular,
        mmmClassification: Int,
        travelTime: TimeInterval? = nil
    ) {
        self.id = id
        self.dailyRecordId = dailyRecordId
        self.startTime = startTime
        self.endTime = endTime
        self.sessionType = sessionType
        self.mmmClassification = mmmClassification
        self.travelTime = travelTime
        self.subsidyAmount = nil
        self.notes = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Duration of the session in hours
    public var durationHours: Double {
        endTime.timeIntervalSince(startTime) / 3600
    }

    /// Duration of the session in seconds
    public var durationSeconds: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Duration as a formatted string (e.g., "2h 30m")
    public var durationFormatted: String {
        let totalSeconds = Int(durationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    /// Total effective hours for subsidy calculation (includes eligible travel time)
    public var effectiveSubsidyHours: Double {
        let baseHours = durationHours
        // Travel time only counts if > 1 hour
        let travelHours = (travelTime ?? 0) > 3600 ? (travelTime! / 3600) : 0
        return baseHours + travelHours
    }

    /// Whether this session is eligible for rural subsidy (MMM 3-7)
    public var isSubsidyEligible: Bool {
        (3...7).contains(mmmClassification)
    }
}
