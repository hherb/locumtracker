import Foundation

/// Represents a work assignment or contract with a healthcare facility
/// Assignments can have multiple daily records and sessions
@Model
public final class Assignment {
    /// Unique identifier for the assignment
    public var id: UUID
    
    /// Base location where the assignment takes place
    public var baseLocation: Location
    
    /// Rate structure for this assignment
    public var rateStructure: RateStructure
    
    /// Fixed daily rate for daily rate assignments
    public var dailyRate: Double?
    
    /// Hourly rate for hourly rate assignments
    public var hourlyRate: Double?
    
    /// Additional rate for on-call availability
    public var onCallRate: Double?
    
    /// Additional rate for emergency call-outs
    public var callOutRate: Double?
    
    /// Special rates for holidays, weekends, nights
    public var specialRates: [SpecialRate]
    
    /// Date range for this assignment
    public var startDate: Date
    public var endDate: Date
    
    /// Current status of the assignment
    public var status: AssignmentStatus
    
    /// Date when this assignment was created
    public var createdAt: Date
    
    /// Date when this assignment was last updated
    public var updatedAt: Date
    
    /// Initialize a new assignment
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - baseLocation: Primary location for the assignment
    ///   - rateStructure: How rates are calculated (daily or hourly)
    ///   - dailyRate: Fixed daily rate (for daily rate assignments)
    ///   - hourlyRate: Hourly rate (for hourly rate assignments)
    ///   - onCallRate: Optional on-call rate
    ///   - callOutRate: Optional call-out rate
    ///   - specialRates: Special rates for holidays/weekends/nights
    ///   - startDate: Assignment start date
    ///   - endDate: Assignment end date
    ///   - status: Current assignment status
    public init(
        id: UUID,
        baseLocation: Location,
        rateStructure: RateStructure,
        dailyRate: Double? = nil,
        hourlyRate: Double? = nil,
        onCallRate: Double? = nil,
        callOutRate: Double? = nil,
        specialRates: [SpecialRate] = [],
        startDate: Date,
        endDate: Date,
        status: AssignmentStatus = .planned
    ) {
        self.id = id
        self.baseLocation = baseLocation
        self.rateStructure = rateStructure
        self.dailyRate = dailyRate
        self.hourlyRate = hourlyRate
        self.onCallRate = onCallRate
        self.callOutRate = callOutRate
        self.specialRates = specialRates
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Returns the date range for this assignment
    public var dateRange: ClosedRange<Date> {
        return startDate...endDate
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
    
    /// Returns the effective rate based on session type
    /// - Parameter sessionType: Type of session to calculate rate for
    /// - Returns: The applicable rate for the session type
    public func rateForSessionType(_ sessionType: SessionType) -> Double? {
        switch sessionType {
        case .regular:
            switch rateStructure {
            case .dailyRate: return dailyRate
            case .hourlyRate: return hourlyRate
            }
        case .onCall: return onCallRate
        case .callOut: return callOutRate
        }
    }
}

/// Defines how assignment rates are calculated
public enum RateStructure: String, CaseIterable, Codable {
    case dailyRate = "daily_rate"
    case hourlyRate = "hourly_rate"
    
    /// Human-readable description of the rate structure
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
    
    /// Human-readable description of the status
    public var description: String {
        switch self {
        case .planned: return "Planned"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

/// Represents special rate conditions for holidays, weekends, nights
public struct SpecialRate: Codable {
    /// Type of special rate
    public var type: SpecialRateType
    
    /// Multiplier to apply to base rate (e.g., 1.5 for 1.5x rate)
    public var multiplier: Double
    
    /// Conditions under which this special rate applies
    public var conditions: [String]
    
    /// Initialize a special rate
    /// - Parameters:
    ///   - type: Type of special rate
    ///   - multiplier: Rate multiplier
    ///   - conditions: List of conditions
    public init(type: SpecialRateType, multiplier: Double, conditions: [String]) {
        self.type = type
        self.multiplier = multiplier
        self.conditions = conditions
    }
}

/// Types of special rates
public enum SpecialRateType: String, CaseIterable, Codable {
    case weekend = "weekend"
    case publicHoliday = "public_holiday"
    case nightShift = "night_shift"
    case emergency = "emergency"
    
    /// Human-readable description of the special rate type
    public var description: String {
        switch self {
        case .weekend: return "Weekend"
        case .publicHoliday: return "Public Holiday"
        case .nightShift: return "Night Shift"
        case .emergency: return "Emergency"
        }
    }
}