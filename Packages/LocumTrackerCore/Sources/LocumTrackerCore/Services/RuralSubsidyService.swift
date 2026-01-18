import Foundation

/// Handles rural subsidy calculations for the Modified Monash Model system
public struct RuralSubsidyService {

    // MARK: - Constants

    /// Base subsidy rates per hour by MMM classification (vocational)
    private static let subsidyRates: [Int: Double] = [
        3: 0.00,   // MMM3: No base subsidy
        4: 15.00,  // MMM4: $15/hour
        5: 25.00,  // MMM5: $25/hour
        6: 45.00,  // MMM6: $45/hour
        7: 65.00   // MMM7: $65/hour
    ]

    /// Travel time must exceed 1 hour to count toward subsidy
    private static let travelTimeThresholdSeconds: TimeInterval = 3600

    /// Quarterly quota hours for full subsidy
    public static let quarterlyQuotaHours: Double = 40

    /// Non-vocational rate multiplier (80% of vocational)
    public static let nonVocationalMultiplier: Double = 0.8

    // MARK: - Public Interface

    /// Returns base subsidy rate for MMM classification
    /// - Parameter mmmClassification: MMM classification (1-7)
    /// - Returns: Base rate per hour in AUD (0 for ineligible classifications)
    public static func getBaseRate(for mmmClassification: Int) -> Double {
        subsidyRates[mmmClassification] ?? 0.0
    }

    /// Whether an MMM classification is eligible for rural subsidy
    /// - Parameter mmmClassification: MMM classification (1-7)
    /// - Returns: True if MMM 3-7
    public static func isEligible(mmmClassification: Int) -> Bool {
        (3...7).contains(mmmClassification)
    }

    /// Calculates rural subsidy for a session
    /// - Parameters:
    ///   - durationSeconds: Session duration in seconds
    ///   - mmmClassification: Modified Monash Model classification (1-7)
    ///   - isVocational: Whether practitioner is vocationally registered
    ///   - travelTimeSeconds: Optional travel time in seconds (only counts if > 1 hour)
    /// - Returns: Subsidy calculation result
    public static func calculateSubsidy(
        durationSeconds: TimeInterval,
        mmmClassification: Int,
        isVocational: Bool,
        travelTimeSeconds: TimeInterval? = nil
    ) -> SubsidyCalculation {
        guard isEligible(mmmClassification: mmmClassification) else {
            return SubsidyCalculation(
                sessionHours: durationSeconds / 3600,
                travelHours: 0,
                effectiveHours: 0,
                baseRate: 0,
                subsidyAmount: 0,
                mmmClassification: mmmClassification,
                isVocational: isVocational,
                eligible: false
            )
        }

        let baseRate = getBaseRate(for: mmmClassification)
        let sessionHours = durationSeconds / 3600

        // Travel time only counts if > 1 hour
        let travelHours: Double
        if let travel = travelTimeSeconds, travel > travelTimeThresholdSeconds {
            travelHours = travel / 3600
        } else {
            travelHours = 0
        }

        let effectiveHours = sessionHours + travelHours
        let rateMultiplier = isVocational ? 1.0 : nonVocationalMultiplier
        let subsidyAmount = effectiveHours * baseRate * rateMultiplier

        return SubsidyCalculation(
            sessionHours: sessionHours,
            travelHours: travelHours,
            effectiveHours: effectiveHours,
            baseRate: baseRate,
            subsidyAmount: subsidyAmount,
            mmmClassification: mmmClassification,
            isVocational: isVocational,
            eligible: true
        )
    }

    /// Calculates total subsidy from hours breakdown by MMM classification
    /// - Parameters:
    ///   - hoursByMMM: Dictionary mapping MMM classification to hours worked
    ///   - isVocational: Whether vocational rates apply
    /// - Returns: Total subsidy amount
    public static func calculateTotalSubsidy(
        hoursByMMM: [Int: Double],
        isVocational: Bool
    ) -> Double {
        let rateMultiplier = isVocational ? 1.0 : nonVocationalMultiplier
        return hoursByMMM.reduce(0.0) { total, entry in
            let (mmm, hours) = entry
            return total + (hours * getBaseRate(for: mmm) * rateMultiplier)
        }
    }
}

// MARK: - Supporting Types

/// Result of subsidy calculation for a single session
public struct SubsidyCalculation: Codable, Sendable {
    public let sessionHours: Double
    public let travelHours: Double
    public let effectiveHours: Double
    public let baseRate: Double
    public let subsidyAmount: Double
    public let mmmClassification: Int
    public let isVocational: Bool
    public let eligible: Bool

    public init(
        sessionHours: Double,
        travelHours: Double,
        effectiveHours: Double,
        baseRate: Double,
        subsidyAmount: Double,
        mmmClassification: Int,
        isVocational: Bool,
        eligible: Bool
    ) {
        self.sessionHours = sessionHours
        self.travelHours = travelHours
        self.effectiveHours = effectiveHours
        self.baseRate = baseRate
        self.subsidyAmount = subsidyAmount
        self.mmmClassification = mmmClassification
        self.isVocational = isVocational
        self.eligible = eligible
    }
}
