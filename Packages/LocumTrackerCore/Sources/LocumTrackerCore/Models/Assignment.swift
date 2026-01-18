import Foundation
import SwiftData

/// Rate structure options for assignments
public enum RateStructure: String, CaseIterable, Codable {
    case dailyRate = "daily_rate"
    case hourlyRate = "hourly_rate"

    public var description: String {
        switch self {
        case .dailyRate: return "Daily Rate"
        case .hourlyRate: return "Hourly Rate"
        }
    }
}

/// Status of an assignment
public enum AssignmentStatus: String, CaseIterable, Codable {
    case planned = "planned"
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"

    public var description: String {
        switch self {
        case .planned: return "Planned"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

/// Represents a work assignment or contract with a healthcare facility
@Model
public final class Assignment {
    public var id: UUID
    public var locationId: UUID
    public var rateStructure: RateStructure
    public var dailyRate: Double?
    public var hourlyRate: Double?
    public var onCallRate: Double?
    public var callOutRate: Double?
    public var startDate: Date
    public var endDate: Date
    public var status: AssignmentStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        locationId: UUID,
        rateStructure: RateStructure,
        dailyRate: Double? = nil,
        hourlyRate: Double? = nil,
        onCallRate: Double? = nil,
        callOutRate: Double? = nil,
        startDate: Date,
        endDate: Date,
        status: AssignmentStatus = .planned
    ) {
        self.id = id
        self.locationId = locationId
        self.rateStructure = rateStructure
        self.dailyRate = dailyRate
        self.hourlyRate = hourlyRate
        self.onCallRate = onCallRate
        self.callOutRate = callOutRate
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Returns date range for this assignment
    public var dateRange: ClosedRange<Date> {
        startDate...endDate
    }

    /// Validates that the assignment has consistent rate configuration
    public var hasValidRateConfiguration: Bool {
        switch rateStructure {
        case .dailyRate:
            return dailyRate != nil && dailyRate! > 0
        case .hourlyRate:
            return hourlyRate != nil && hourlyRate! > 0
        }
    }
}
