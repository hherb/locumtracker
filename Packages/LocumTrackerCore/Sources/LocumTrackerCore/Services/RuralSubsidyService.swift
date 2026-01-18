import Foundation

/// Handles rural subsidy calculations and compliance tracking
/// Implements Modified Monash Model subsidy system for Australian healthcare
public struct RuralSubsidyService {
    
    // MARK: - Constants
    
    /// Base subsidy rates per hour by MMM classification
    private enum SubsidyRates {
        static let mmm3 = 0.00      // MMM3: No base subsidy
        static let mmm4 = 15.00     // MMM4: $15/hour
        static let mmm5 = 25.00     // MMM5: $25/hour
        static let mmm6 = 45.00     // MMM6: $45/hour
        static let mmm7 = 65.00     // MMM7: $65/hour
    }
    
    /// Travel time threshold for subsidy eligibility
    private static let travelTimeThresholdSeconds: TimeInterval = 3600 // 1 hour
    
    /// Quarterly quota hours for full subsidy
    public static let quarterlyQuotaHours: Double = 40
    
    // MARK: - Public Interface
    
    /// Calculates rural subsidy for a session based on duration and location
    /// - Parameters:
    ///   - duration: Session duration in seconds
    ///   - mmmClassification: Modified Monash Model classification (1-7)
    ///   - isVocational: Whether practitioner is vocationally registered
    ///   - travelTime: Optional travel time in seconds
    /// - Returns: Detailed subsidy calculation breakdown
    public static func calculateSessionSubsidy(
        duration: TimeInterval,
        mmmClassification: Int,
        isVocational: Bool,
        travelTime: TimeInterval? = nil
    ) -> SubsidyCalculation {
        
        // Validate MMM classification
        guard (3...7).contains(mmmClassification) else {
            return SubsidyCalculation(
                sessionHours: duration / 3600,
                travelHours: 0,
                effectiveHours: 0,
                baseRate: 0,
                subsidyAmount: 0,
                mmmClassification: mmmClassification,
                isVocational: isVocational,
                eligible: false,
                reason: "MMM classification \(mmmClassification) is not eligible for rural subsidy"
            )
        }
        
        // Get base rate for MMM classification
        let baseRate = getBaseRateForMMM(mmmClassification)
        
        // Calculate hours
        let sessionHours = duration / 3600
        let travelHours = getTravelHours(travelTime)
        let effectiveHours = sessionHours + travelHours
        
        // Apply vocational multiplier
        let rateMultiplier = isVocational ? 1.0 : 0.8
        let subsidyAmount = effectiveHours * baseRate * rateMultiplier
        
        return SubsidyCalculation(
            sessionHours: sessionHours,
            travelHours: travelHours,
            effectiveHours: effectiveHours,
            baseRate: baseRate,
            subsidyAmount: subsidyAmount,
            mmmClassification: mmmClassification,
            isVocational: isVocational,
            eligible: true,
            reason: nil
        )
    }
    
    /// Calculates quarterly quota progress from session data
    /// - Parameters:
    ///   - sessions: Array of sessions for the quarter
    ///   - quarterDate: First day of the quarter
    /// - Returns: Detailed progress breakdown
    public static func calculateQuarterlyProgress(
        sessions: [Session],
        quarterDate: Date
    ) -> QuarterlyProgress {
        
        // Filter sessions by MMM classification (3-7 only)
        let eligibleSessions = sessions.filter { session in
            (3...7).contains(session.mmmClassification)
        }
        
        // Group sessions by MMM classification and calculate hours
        var mmmHours: [Int: Double] = [:]
        for session in eligibleSessions {
            let currentHours = mmmHours[session.mmmClassification, default: 0.0]
            mmmHours[session.mmmClassification] = currentHours + session.effectiveSubsidyHours
        }
        
        // Extract hours for each MMM classification
        let mmm3Hours = mmmHours[3] ?? 0.0
        let mmm4Hours = mmmHours[4] ?? 0.0
        let mmm5Hours = mmmHours[5] ?? 0.0
        let mmm6Hours = mmmHours[6] ?? 0.0
        let mmm7Hours = mmmHours[7] ?? 0.0
        
        // Calculate totals
        let totalHours = mmm3Hours + mmm4Hours + mmm5Hours + mmm6Hours + mmm7Hours
        let quotaMet = totalHours >= quarterlyQuotaHours
        let progressPercentage = quarterlyQuotaHours > 0 ? (totalHours / quarterlyQuotaHours) * 100 : 0
        
        // Calculate projected total subsidy
        let projectedSubsidy = calculateProjectedSubsidy(mmmHours: mmmHours, isVocational: true) // Default to vocational
        
        // Determine days remaining in quarter
        let daysRemaining = calculateDaysRemainingInQuarter(quarterDate)
        let isAtRisk = !quotaMet && daysRemaining < 30
        
        return QuarterlyProgress(
            mmm3Hours: mmm3Hours,
            mmm4Hours: mmm4Hours,
            mmm5Hours: mmm5Hours,
            mmm6Hours: mmm6Hours,
            mmm7Hours: mmm7Hours,
            totalHours: totalHours,
            targetHours: quarterlyQuotaHours,
            progressPercentage: progressPercentage,
            quotaMet: quotaMet,
            remainingHours: max(0, quarterlyQuotaHours - totalHours),
            daysRemaining: daysRemaining,
            projectedSubsidy: projectedSubsidy,
            warningLevel: determineWarningLevel(quotaMet: quotaMet, progressPercentage: progressPercentage, daysRemaining: daysRemaining),
            isAtRisk: isAtRisk
        )
    }
    
    /// Validates MMM classification
    /// - Parameter mmmClassification: MMM classification to validate
    /// - Returns: True if classification is valid (1-7)
    public static func isValidMMMClassification(_ mmmClassification: Int) -> Bool {
        return (1...7).contains(mmmClassification)
    }
    
    /// Returns base subsidy rate for MMM classification
    /// - Parameter mmmClassification: MMM classification (1-7)
    /// - Returns: Base rate per hour in AUD
    public static func getBaseRateForMMM(_ mmmClassification: Int) -> Double {
        switch mmmClassification {
        case 3: return SubsidyRates.mmm3
        case 4: return SubsidyRates.mmm4
        case 5: return SubsidyRates.mmm5
        case 6: return SubsidyRates.mmm6
        case 7: return SubsidyRates.mmm7
        default: return 0.0
        }
    }
    
    // MARK: - Private Helpers
    
    /// Calculates travel hours that count toward subsidy
    /// Travel time must exceed 1 hour to count
    /// - Parameter travelTime: Travel time in seconds
    /// - Returns: Travel hours that count toward subsidy
    private static func getTravelHours(_ travelTime: TimeInterval?) -> Double {
        guard let travelTime = travelTime else { return 0 }
        return travelTime > travelTimeThresholdSeconds ? travelTime / 3600 : 0
    }
    
    /// Calculates projected subsidy from MMM hours breakdown
    /// - Parameters:
    ///   - mmmHours: Hours by MMM classification
    ///   - isVocational: Whether vocational rates apply
    /// - Returns: Projected subsidy amount
    private static func calculateProjectedSubsidy(mmmHours: [Int: Double], isVocational: Bool) -> Double {
        let rateMultiplier = isVocational ? 1.0 : 0.8
        var totalSubsidy = 0.0
        
        for (mmm, hours) in mmmHours {
            let baseRate = getBaseRateForMMM(mmm)
            totalSubsidy += hours * baseRate * rateMultiplier
        }
        
        return totalSubsidy
    }
    
    /// Calculates days remaining in quarter from quarter start date
    /// - Parameter quarterDate: First day of the quarter
    /// - Returns: Number of days remaining in quarter
    private static func calculateDaysRemainingInQuarter(_ quarterDate: Date) -> Int {
        let calendar = Calendar.current
        guard let startOfQuarter = calendar.dateInterval(of: .quarter, for: quarterDate)?.start,
              let endOfQuarter = calendar.dateInterval(of: .quarter, for: quarterDate)?.end else {
            return 0
        }
        
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: endOfQuarter)
        return max(0, components.day ?? 0)
    }
    
    /// Determines warning level based on quota progress
    /// - Parameters:
    ///   - quotaMet: Whether quota has been met
    ///   - progressPercentage: Progress toward quota
    ///   - daysRemaining: Days remaining in quarter
    /// - Returns: Warning level for UI display
    private static func determineWarningLevel(
        quotaMet: Bool,
        progressPercentage: Double,
        daysRemaining: Int
    ) -> WarningLevel {
        if quotaMet {
            return .success
        } else if progressPercentage >= 75 && daysRemaining >= 30 {
            return .low
        } else if progressPercentage >= 50 && daysRemaining >= 14 {
            return .medium
        } else {
            return .high
        }
    }
}

// MARK: - Supporting Types

/// Result of subsidy calculation for a single session
public struct SubsidyCalculation: Codable {
    /// Actual session hours worked
    public let sessionHours: Double
    
    /// Travel hours that count toward subsidy
    public let travelHours: Double
    
    /// Total effective hours (session + eligible travel)
    public let effectiveHours: Double
    
    /// Base subsidy rate per hour
    public let baseRate: Double
    
    /// Total subsidy amount for the session
    public let subsidyAmount: Double
    
    /// MMM classification used for calculation
    public let mmmClassification: Int
    
    /// Whether vocational rates were applied
    public let isVocational: Bool
    
    /// Whether this session is eligible for subsidy
    public let eligible: Bool
    
    /// Reason if not eligible for subsidy
    public let reason: String?
}

/// Result of quarterly quota calculation
public struct QuarterlyProgress: Codable {
    /// Hours in MMM3 locations
    public let mmm3Hours: Double
    
    /// Hours in MMM4 locations
    public let mmm4Hours: Double
    
    /// Hours in MMM5 locations
    public let mmm5Hours: Double
    
    /// Hours in MMM6 locations
    public let mmm6Hours: Double
    
    /// Hours in MMM7 locations
    public let mmm7Hours: Double
    
    /// Total hours across all MMM3-7 locations
    public let totalHours: Double
    
    /// Target hours for full quarterly subsidy
    public let targetHours: Double
    
    /// Progress percentage toward quota
    public let progressPercentage: Double
    
    /// Whether quarterly quota has been met
    public let quotaMet: Bool
    
    /// Remaining hours needed to meet quota
    public let remainingHours: Double
    
    /// Days remaining in the quarter
    public let daysRemaining: Int
    
    /// Projected total subsidy for the quarter
    public let projectedSubsidy: Double
    
    /// Warning level for UI display
    public let warningLevel: WarningLevel
    
    /// Whether user is at risk of not meeting quota
    public let isAtRisk: Bool
}