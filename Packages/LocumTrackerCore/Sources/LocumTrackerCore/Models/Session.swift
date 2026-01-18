import Foundation

/// Represents individual work sessions within a daily record
/// Sessions can have different locations and rates within the same day
@Model
public final class Session {
    /// Unique identifier for the session
    public var id: UUID
    
    /// Start time of the session
    public var startTime: Date
    
    /// End time of the session
    public var endTime: Date
    
    /// Location where this session took place (can differ from assignment base location)
    public var location: Location
    
    /// Type of session (regular, on-call, call-out)
    public var sessionType: SessionType
    
    /// Travel time in seconds (if applicable for subsidy calculation)
    /// Travel time counts toward subsidy if >1 hour (3600 seconds)
    public var travelTime: TimeInterval?
    
    /// MMM classification of the location at time of session
    /// Used for rural subsidy calculations
    public var mmmClassification: Int
    
    /// Calculated subsidy amount for this session
    /// Nil for sessions in MMM1-2 locations
    public var subsidyAmount: Double?
    
    /// Regular earnings for this session (excluding subsidy)
    public var regularEarnings: Double?
    
    /// Date when this session record was created
    public var createdAt: Date
    
    /// Date when this session record was last updated
    public var updatedAt: Date
    
    /// Initialize a new session
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - startTime: Start time of the session
    ///   - endTime: End time of the session
    ///   - location: Location where session took place
    ///   - sessionType: Type of session
    ///   - travelTime: Optional travel time in seconds
    ///   - mmmClassification: MMM classification (1-7)
    public init(
        id: UUID,
        startTime: Date,
        endTime: Date,
        location: Location,
        sessionType: SessionType,
        travelTime: TimeInterval? = nil,
        mmmClassification: Int
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.sessionType = sessionType
        self.travelTime = travelTime
        self.mmmClassification = mmmClassification
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Returns the duration of the session in hours
    public var durationHours: Double {
        return endTime.timeIntervalSince(startTime) / 3600
    }
    
    /// Returns the duration of the session in seconds
    public var durationSeconds: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Returns the duration as a formatted string (e.g., "2h 30m")
    public var durationFormatted: String {
        let seconds = Int(durationSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if hours > 0 {
            return String(format: "%dh", hours)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    /// Determines if this session is eligible for rural subsidy
    public var isSubsidyEligible: Bool {
        return (3...7).contains(mmmClassification)
    }
    
    /// Determines if travel time counts toward subsidy (must be >1 hour)
    public var travelTimeCountsForSubsidy: Bool {
        guard let travelTime = travelTime else { return false }
        return travelTime > 3600 // 1 hour in seconds
    }
    
    /// Returns total effective hours for subsidy calculation
    /// Includes travel time if it qualifies
    public var effectiveSubsidyHours: Double {
        if !isSubsidyEligible {
            return 0
        }
        
        let sessionHours = durationHours
        let travelHours = travelTimeCountsForSubsidy ? (travelTime ?? 0) / 3600 : 0
        
        return sessionHours + travelHours
    }
    
    /// Updates the session timestamp
    public func touch() {
        self.updatedAt = Date()
    }
}

/// Type of work session
public enum SessionType: String, CaseIterable, Codable {
    case regular = "regular"
    case onCall = "on_call"
    case callOut = "call_out"
    
    /// Human-readable description of the session type
    public var description: String {
        switch self {
        case .regular: return "Regular"
        case .onCall: return "On-Call"
        case .callOut: return "Call-Out"
        }
    }
    
    /// Symbol for the session type
    public var symbol: String {
        switch self {
        case .regular: return "🏥"
        case .onCall: return "📞"
        case .callOut: return "🚨"
        }
    }
}