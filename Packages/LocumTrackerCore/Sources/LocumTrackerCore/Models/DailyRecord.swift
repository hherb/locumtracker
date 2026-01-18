import Foundation

/// Container for daily work sessions and earnings
/// Links multiple sessions within a single work day
@Model
public final class DailyRecord {
    /// Unique identifier for daily record
    public var id: UUID
    
    /// ID of the assignment this daily record belongs to
    public var assignmentId: UUID
    
    /// Date of the work day
    public var date: Date
    
    /// All work sessions for this day
    public var sessions: [Session]
    
    /// Applied rates for this day (for invoicing transparency)
    public var appliedRates: [AppliedRate]
    
    /// Total earnings for the day (excluding subsidies)
    public var totalEarnings: Double
    
    /// Rural subsidy earnings for the day
    public var subsidyEarnings: Double?
    
    /// Notes for the day (e.g., weather, special circumstances)
    public var notes: String?
    
    /// Date when this daily record was created
    public var createdAt: Date
    
    /// Date when this daily record was last updated
    public var updatedAt: Date
    
    /// Initialize a new daily record
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - assignmentId: ID of parent assignment
    ///   - date: Work date
    ///   - sessions: Array of work sessions for the day
    ///   - notes: Optional notes for the day
    public init(
        id: UUID,
        assignmentId: UUID,
        date: Date,
        sessions: [Session] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.date = date
        self.sessions = sessions
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // Initialize with empty applied rates and calculate earnings
        self.appliedRates = []
        self.calculateEarnings()
    }
    
    /// Returns total hours worked across all sessions
    public var totalHours: Double {
        return sessions.reduce(0) { total, session in
            total + session.durationHours
        }
    }
    
    /// Returns total subsidy-eligible hours
    public var subsidyEligibleHours: Double {
        return sessions.reduce(0) { total, session in
            total + (session.isSubsidyEligible ? session.effectiveSubsidyHours : 0)
        }
    }
    
    /// Returns all unique locations worked at during the day
    public var locations: [Location] {
        return Array(Set(sessions.map { $0.location }))
    }
    
    /// Returns the primary location (where most time was spent)
    public var primaryLocation: Location? {
        return sessions.max { session1, session2 in
            session1.durationSeconds > session2.durationSeconds
        }?.location
    }
    
    /// Determines if this day has any subsidy-eligible sessions
    public var hasSubsidyEligibleWork: Bool {
        return sessions.contains { $0.isSubsidyEligible }
    }
    
    /// Returns formatted total hours (e.g., "8.5 hours")
    public var formattedTotalHours: String {
        return String(format: "%.1f hours", totalHours)
    }
    
    /// Returns earnings breakdown including subsidies
    public var earningsBreakdown: EarningsBreakdown {
        let regularEarnings = totalEarnings
        let subsidyEarnings = self.subsidyEarnings ?? 0
        let totalEarnings = regularEarnings + subsidyEarnings
        
        return EarningsBreakdown(
            regularEarnings: regularEarnings,
            subsidyEarnings: subsidyEarnings,
            totalEarnings: totalEarnings,
            totalHours: totalHours,
            sessions: sessions
        )
    }
    
    /// Adds a new session to the daily record
    /// - Parameter session: Session to add
    public func addSession(_ session: Session) {
        sessions.append(session)
        calculateEarnings()
        touch()
    }
    
    /// Removes a session from the daily record
    /// - Parameter sessionId: ID of session to remove
    public func removeSession(id sessionId: UUID) {
        sessions.removeAll { $0.id == sessionId }
        calculateEarnings()
        touch()
    }
    
    /// Updates an existing session
    /// - Parameter session: Updated session
    public func updateSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            calculateEarnings()
            touch()
        }
    }
    
    /// Recalculates earnings and applied rates
    private func calculateEarnings() {
        var total = 0.0
        var subsidyTotal = 0.0
        var newAppliedRates: [AppliedRate] = []
        
        // Calculate earnings for each session
        for session in sessions {
            // Calculate session earnings based on session type
            let sessionEarnings = calculateSessionEarnings(session)
            total += sessionEarnings.regular
            
            // Add to subsidy if eligible
            if let subsidy = session.subsidyAmount {
                subsidyTotal += subsidy
            }
            
            // Create applied rate record
            let appliedRate = AppliedRate(
                sessionType: session.sessionType.rawValue,
                rate: sessionEarnings.rate,
                hours: session.durationHours,
                amount: sessionEarnings.regular,
                subsidyAmount: session.subsidyAmount
            )
            newAppliedRates.append(appliedRate)
        }
        
        totalEarnings = total
        subsidyEarnings = subsidyTotal
        appliedRates = newAppliedRates
    }
    
    /// Calculates earnings for a specific session
    /// - Parameter session: Session to calculate earnings for
    /// - Returns: Rate and earnings breakdown
    private func calculateSessionEarnings(_ session: Session) -> (rate: Double, regular: Double) {
        // This would typically use assignment rates
        // For now, use a default calculation that would come from assignment
        let defaultHourlyRate = 50.0 // This would come from assignment
        
        switch session.sessionType {
        case .regular:
            return (defaultHourlyRate, defaultHourlyRate * session.durationHours)
        case .onCall:
            let onCallRate = defaultHourlyRate * 0.25 // 25% of regular rate
            return (onCallRate, onCallRate * session.durationHours)
        case .callOut:
            let callOutRate = defaultHourlyRate * 0.5 // 50% of regular rate
            return (callOutRate, callOutRate * session.durationHours)
        }
    }
    
    /// Updates the last updated timestamp
    public func touch() {
        self.updatedAt = Date()
    }
}

/// Represents an applied rate for transparency in invoicing
public struct AppliedRate: Codable {
    /// Type of session this rate applies to
    public var sessionType: String
    
    /// Rate per hour applied
    public var rate: Double
    
    /// Number of hours at this rate
    public var hours: Double
    
    /// Total amount earned at this rate
    public var amount: Double
    
    /// Subsidy amount for this rate (if applicable)
    public var subsidyAmount: Double?
    
    /// Initialize an applied rate
    /// - Parameters:
    ///   - sessionType: Type of session
    ///   - rate: Rate per hour
    ///   - hours: Number of hours
    ///   - amount: Total amount earned
    ///   - subsidyAmount: Optional subsidy amount
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
    
    /// Returns formatted rate for display
    public var formattedRate: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: rate)) ?? "$0.00"
    }
    
    /// Returns formatted amount for display
    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

/// Earnings breakdown for reporting
public struct EarningsBreakdown: Codable {
    /// Regular earnings (excluding subsidies)
    public var regularEarnings: Double
    
    /// Rural subsidy earnings
    public var subsidyEarnings: Double
    
    /// Total earnings (regular + subsidy)
    public var totalEarnings: Double
    
    /// Total hours worked
    public var totalHours: Double
    
    /// Sessions that contributed to these earnings
    public var sessions: [Session]
    
    /// Initialize earnings breakdown
    /// - Parameters:
    ///   - regularEarnings: Regular earnings
    ///   - subsidyEarnings: Subsidy earnings
    ///   - totalEarnings: Total earnings
    ///   - totalHours: Total hours
    ///   - sessions: Contributing sessions
    public init(
        regularEarnings: Double,
        subsidyEarnings: Double,
        totalEarnings: Double,
        totalHours: Double,
        sessions: [Session]
    ) {
        self.regularEarnings = regularEarnings
        self.subsidyEarnings = subsidyEarnings
        self.totalEarnings = totalEarnings
        self.totalHours = totalHours
        self.sessions = sessions
    }
    
    /// Returns formatted total earnings
    public var formattedTotalEarnings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: totalEarnings)) ?? "$0.00"
    }
    
    /// Returns formatted subsidy earnings
    public var formattedSubsidyEarnings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: subsidyEarnings)) ?? "$0.00"
    }
    
    /// Returns formatted regular earnings
    public var formattedRegularEarnings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: regularEarnings)) ?? "$0.00"
    }
}