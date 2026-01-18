import Foundation

/// Handles earnings calculations for assignments and daily records
/// Supports both daily rate and hourly rate structures
public struct EarningsService {
    
    // MARK: - Constants
    
    /// Default on-call rate as percentage of regular rate
    private static let defaultOnCallRatePercentage: Double = 0.25
    
    /// Default call-out rate as percentage of regular rate
    private static let defaultCallOutRatePercentage: Double = 0.5
    
    // MARK: - Public Interface
    
    /// Calculates earnings for a daily record based on assignment rates and sessions
    /// - Parameters:
    ///   - dailyRecord: Daily record with sessions
    ///   - assignment: Parent assignment with rate structure
    /// - Returns: Detailed earnings breakdown
    public static func calculateDailyEarnings(
        dailyRecord: DailyRecord,
        assignment: Assignment
    ) -> EarningsBreakdown {
        
        var regularEarnings = 0.0
        var sessionEarnings: [SessionEarning] = []
        
        // Calculate earnings for each session
        for session in dailyRecord.sessions {
            let sessionResult = calculateSessionEarnings(session: session, assignment: assignment)
            regularEarnings += sessionResult.amount
            sessionEarnings.append(sessionResult)
        }
        
        // Calculate subsidy earnings
        let subsidyEarnings = calculateSubsidyEarnings(sessions: dailyRecord.sessions)
        
        return EarningsBreakdown(
            regularEarnings: regularEarnings,
            subsidyEarnings: subsidyEarnings,
            totalEarnings: regularEarnings + subsidyEarnings,
            totalHours: dailyRecord.totalHours,
            sessions: dailyRecord.sessions,
            sessionEarnings: sessionEarnings
        )
    }
    
    /// Calculates earnings for a single session based on assignment rates
    /// - Parameters:
    ///   - session: Session to calculate earnings for
    ///   - assignment: Assignment with rate structure
    /// - Returns: Session earning details
    public static func calculateSessionEarnings(
        session: Session,
        assignment: Assignment
    ) -> SessionEarning {
        
        let durationHours = session.durationHours
        
        // Get rate based on session type and assignment structure
        let rate = assignment.rateForSessionType(session.sessionType) ?? 0.0
        
        // Calculate amount
        var amount: Double
        
        switch session.sessionType {
        case .regular:
            amount = calculateRegularEarnings(
                durationHours: durationHours,
                rateStructure: assignment.rateStructure,
                rate: rate
            )
        case .onCall:
            amount = calculateOnCallEarnings(
                durationHours: durationHours,
                baseRate: assignment.hourlyRate ?? 0.0,
                onCallRate: assignment.onCallRate
            )
        case .callOut:
            amount = calculateCallOutEarnings(
                callOutRate: assignment.callOutRate
            )
        }
        
        return SessionEarning(
            sessionId: session.id,
            sessionType: session.sessionType,
            rate: rate,
            hours: durationHours,
            amount: amount
        )
    }
    
    /// Calculates earnings for an assignment over its date range
    /// - Parameters:
    ///   - assignment: Assignment to calculate earnings for
    ///   - dailyRecords: Array of daily records for the assignment
    /// - Returns: Assignment earnings summary
    public static func calculateAssignmentEarnings(
        assignment: Assignment,
        dailyRecords: [DailyRecord]
    ) -> AssignmentEarnings {
        
        // Filter daily records for this assignment
        let assignmentRecords = dailyRecords.filter { $0.assignmentId == assignment.id }
        
        // Calculate total earnings across all daily records
        var totalRegularEarnings = 0.0
        var totalSubsidyEarnings = 0.0
        var totalHours = 0.0
        
        for dailyRecord in assignmentRecords {
            let breakdown = calculateDailyEarnings(dailyRecord: dailyRecord, assignment: assignment)
            totalRegularEarnings += breakdown.regularEarnings
            totalSubsidyEarnings += breakdown.subsidyEarnings
            totalHours += breakdown.totalHours
        }
        
        return AssignmentEarnings(
            assignmentId: assignment.id,
            regularEarnings: totalRegularEarnings,
            subsidyEarnings: totalSubsidyEarnings,
            totalEarnings: totalRegularEarnings + totalSubsidyEarnings,
            totalHours: totalHours,
            dailyRecords: assignmentRecords
        )
    }
    
    /// Calculates projected earnings based on assignment parameters
    /// - Parameters:
    ///   - rateStructure: Daily or hourly rate structure
    ///   - dailyRate: Daily rate (for daily rate assignments)
    ///   - hourlyRate: Hourly rate (for hourly rate assignments)
    ///   - expectedHours: Expected hours per day/week
    ///   - numberOfDays: Number of days in assignment
    /// - Returns: Projected earnings breakdown
    public static func calculateProjectedEarnings(
        rateStructure: RateStructure,
        dailyRate: Double?,
        hourlyRate: Double?,
        expectedHours: Double,
        numberOfDays: Int
    ) -> ProjectedEarnings {
        
        let regularEarnings: Double
        
        switch rateStructure {
        case .dailyRate:
            regularEarnings = (dailyRate ?? 0.0) * Double(numberOfDays)
        case .hourlyRate:
            regularEarnings = (hourlyRate ?? 0.0) * expectedHours * Double(numberOfDays)
        }
        
        return ProjectedEarnings(
            rateStructure: rateStructure,
            dailyRate: dailyRate,
            hourlyRate: hourlyRate,
            expectedHours: expectedHours,
            numberOfDays: numberOfDays,
            regularEarnings: regularEarnings,
            subsidyEarnings: 0.0, // Would need location data to estimate
            totalEarnings: regularEarnings
        )
    }
    
    // MARK: - Private Helpers
    
    /// Calculates regular earnings based on rate structure
    /// - Parameters:
    ///   - durationHours: Hours worked
    ///   - rateStructure: Daily or hourly rate structure
    ///   - rate: Rate to apply
    /// - Returns: Regular earnings amount
    private static func calculateRegularEarnings(
        durationHours: Double,
        rateStructure: RateStructure,
        rate: Double
    ) -> Double {
        
        switch rateStructure {
        case .dailyRate:
            return rate // Daily rate is fixed regardless of hours
        case .hourlyRate:
            return rate * durationHours
        }
    }
    
    /// Calculates on-call earnings based on base and on-call rates
    /// - Parameters:
    ///   - durationHours: On-call duration in hours
    ///   - baseRate: Base hourly rate
    ///   - onCallRate: On-call hourly rate
    /// - Returns: On-call earnings amount
    private static func calculateOnCallEarnings(
        durationHours: Double,
        baseRate: Double,
        onCallRate: Double?
    ) -> Double {
        
        let rate = onCallRate ?? (baseRate * defaultOnCallRatePercentage)
        return rate * durationHours
    }
    
    /// Calculates call-out earnings
    /// - Parameters:
    ///   - callOutRate: Call-out rate per occurrence
    /// - Returns: Call-out earnings amount
    private static func calculateCallOutEarnings(
        callOutRate: Double?
    ) -> Double {
        
        return callOutRate ?? 0.0 // Fixed amount per call-out
    }
    
    /// Calculates total subsidy earnings from sessions
    /// - Parameter sessions: Array of sessions
    /// - Returns: Total subsidy earnings
    private static func calculateSubsidyEarnings(sessions: [Session]) -> Double {
        return sessions.compactMap { $0.subsidyAmount }.reduce(0, +)
    }
}

// MARK: - Supporting Types

/// Earnings breakdown for a single session
public struct SessionEarning: Codable {
    /// ID of the session
    public let sessionId: UUID
    
    /// Type of session
    public let sessionType: SessionType
    
    /// Rate applied to the session
    public let rate: Double
    
    /// Number of hours in the session
    public let hours: Double
    
    /// Total earnings for the session
    public let amount: Double
    
    /// Initialize session earning
    /// - Parameters:
    ///   - sessionId: Session ID
    ///   - sessionType: Type of session
    ///   - rate: Rate applied
    ///   - hours: Hours worked
    ///   - amount: Total amount earned
    public init(
        sessionId: UUID,
        sessionType: SessionType,
        rate: Double,
        hours: Double,
        amount: Double
    ) {
        self.sessionId = sessionId
        self.sessionType = sessionType
        self.rate = rate
        self.hours = hours
        self.amount = amount
    }
    
    /// Returns formatted amount for display
    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    /// Returns formatted rate for display
    public var formattedRate: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: rate)) ?? "$0.00"
    }
}

/// Earnings summary for an entire assignment
public struct AssignmentEarnings: Codable {
    /// ID of the assignment
    public let assignmentId: UUID
    
    /// Total regular earnings (excluding subsidies)
    public let regularEarnings: Double
    
    /// Total subsidy earnings
    public let subsidyEarnings: Double
    
    /// Total earnings (regular + subsidy)
    public let totalEarnings: Double
    
    /// Total hours worked across assignment
    public let totalHours: Double
    
    /// Daily records that contributed to these earnings
    public let dailyRecords: [DailyRecord]
    
    /// Initialize assignment earnings
    /// - Parameters:
    ///   - assignmentId: Assignment ID
    ///   - regularEarnings: Regular earnings
    ///   - subsidyEarnings: Subsidy earnings
    ///   - totalEarnings: Total earnings
    ///   - totalHours: Total hours
    ///   - dailyRecords: Contributing daily records
    public init(
        assignmentId: UUID,
        regularEarnings: Double,
        subsidyEarnings: Double,
        totalEarnings: Double,
        totalHours: Double,
        dailyRecords: [DailyRecord]
    ) {
        self.assignmentId = assignmentId
        self.regularEarnings = regularEarnings
        self.subsidyEarnings = subsidyEarnings
        self.totalEarnings = totalEarnings
        self.totalHours = totalHours
        self.dailyRecords = dailyRecords
    }
    
    /// Returns formatted total earnings
    public var formattedTotalEarnings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: totalEarnings)) ?? "$0.00"
    }
    
    /// Returns average earnings per day
    public var averageEarningsPerDay: Double {
        guard !dailyRecords.isEmpty else { return 0 }
        return totalEarnings / Double(dailyRecords.count)
    }
    
    /// Returns average hours per day
    public var averageHoursPerDay: Double {
        guard !dailyRecords.isEmpty else { return 0 }
        return totalHours / Double(dailyRecords.count)
    }
}

/// Projected earnings for assignment planning
public struct ProjectedEarnings: Codable {
    /// Rate structure being used for projection
    public let rateStructure: RateStructure
    
    /// Daily rate (if applicable)
    public let dailyRate: Double?
    
    /// Hourly rate (if applicable)
    public let hourlyRate: Double?
    
    /// Expected hours per period
    public let expectedHours: Double
    
    /// Number of days in assignment
    public let numberOfDays: Int
    
    /// Projected regular earnings
    public let regularEarnings: Double
    
    /// Projected subsidy earnings (would need location data)
    public let subsidyEarnings: Double
    
    /// Total projected earnings
    public let totalEarnings: Double
    
    /// Initialize projected earnings
    /// - Parameters:
    ///   - rateStructure: Rate structure
    ///   - dailyRate: Daily rate
    ///   - hourlyRate: Hourly rate
    ///   - expectedHours: Expected hours
    ///   - numberOfDays: Number of days
    ///   - regularEarnings: Regular earnings
    ///   - subsidyEarnings: Subsidy earnings
    ///   - totalEarnings: Total earnings
    public init(
        rateStructure: RateStructure,
        dailyRate: Double?,
        hourlyRate: Double?,
        expectedHours: Double,
        numberOfDays: Int,
        regularEarnings: Double,
        subsidyEarnings: Double,
        totalEarnings: Double
    ) {
        self.rateStructure = rateStructure
        self.dailyRate = dailyRate
        self.hourlyRate = hourlyRate
        self.expectedHours = expectedHours
        self.numberOfDays = numberOfDays
        self.regularEarnings = regularEarnings
        self.subsidyEarnings = subsidyEarnings
        self.totalEarnings = totalEarnings
    }
    
    /// Returns formatted total earnings
    public var formattedTotalEarnings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: totalEarnings)) ?? "$0.00"
    }
    
    /// Returns formatted regular earnings
    public var formattedRegularEarnings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: regularEarnings)) ?? "$0.00"
    }
    
    /// Returns expected earnings per day
    public var expectedEarningsPerDay: Double {
        return numberOfDays > 0 ? totalEarnings / Double(numberOfDays) : 0
    }
    
    /// Returns expected earnings per hour
    public var expectedEarningsPerHour: Double {
        let totalExpectedHours = expectedHours * Double(numberOfDays)
        return totalExpectedHours > 0 ? totalEarnings / totalExpectedHours : 0
    }
}