// LocumTracker
// Copyright (C) 2025 Dr Horst Herb
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

/// Registration status for WIP Doctor Stream
public enum RegistrationStatus: String, CaseIterable, Codable, Sendable {
    case vocationallyRegistered = "VR"
    case onApprovedTraining = "TRAINING"
    case nonVocational = "NON_VR"

    public var description: String {
        switch self {
        case .vocationallyRegistered: return "Vocationally Registered"
        case .onApprovedTraining: return "On Approved Training Pathway"
        case .nonVocational: return "Non-Vocational"
        }
    }

    /// Whether this status qualifies for full (100%) payment rates
    public var qualifiesForFullRate: Bool {
        self == .vocationallyRegistered || self == .onApprovedTraining
    }
}

/// Handles rural subsidy calculations for the WIP Doctor Stream (FPS)
public struct RuralSubsidyService {

    // MARK: - FPS Session Constants

    /// Minimum session duration in hours to count as a valid session
    public static let minimumSessionHours: Double = 3.0

    /// Maximum sessions countable per day
    public static let maximumSessionsPerDay: Int = 2

    /// Minimum sessions required for an active quarter
    public static let quarterlyMinimumSessions: Int = 21

    /// Maximum sessions counted per quarter
    public static let quarterlyMaximumSessions: Int = 104

    /// Non-vocational payment multiplier (80% of full rate)
    public static let nonVocationalMultiplier: Double = 0.8

    // MARK: - Reference Period Constants

    /// Active quarters required for new participants in MMM 3-5
    public static let newParticipantMMM35RequiredQuarters: Int = 8

    /// Reference period in quarters for new participants in MMM 3-5
    public static let newParticipantMMM35ReferencePeriod: Int = 16

    /// Active quarters required for new participants in MMM 6-7
    public static let newParticipantMMM67RequiredQuarters: Int = 4

    /// Reference period in quarters for new participants in MMM 6-7
    public static let newParticipantMMM67ReferencePeriod: Int = 8

    /// Active quarters required for continuing participants
    public static let continuingRequiredQuarters: Int = 4

    /// Reference period in quarters for continuing participants
    public static let continuingReferencePeriod: Int = 8

    // MARK: - Payment Matrix (VR or on approved training pathway)

    /// Annual payment amounts by year level and MMM classification (VR rates)
    private static let paymentMatrixVR: [Int: [Int: Double]] = [
        1: [3: 4_500, 4: 7_500, 5: 12_000, 6: 25_000, 7: 47_000],
        2: [3: 7_500, 4: 12_000, 5: 15_000, 6: 30_000, 7: 50_000],
        3: [3: 10_000, 4: 15_000, 5: 18_000, 6: 35_000, 7: 55_000],
        4: [3: 12_000, 4: 18_000, 5: 21_000, 6: 40_000, 7: 60_000]
    ]

    // MARK: - Public Interface

    /// Whether an MMM classification is eligible for WIP subsidy
    /// - Parameter mmmClassification: MMM classification (1-7)
    /// - Returns: True if MMM 3-7
    public static func isEligible(mmmClassification: Int) -> Bool {
        (3...7).contains(mmmClassification)
    }

    /// Validates whether a session meets FPS requirements
    /// - Parameter durationHours: Duration of the session in hours
    /// - Returns: True if session duration meets minimum (3 hours)
    public static func isValidSession(durationHours: Double) -> Bool {
        durationHours >= minimumSessionHours
    }

    /// Gets the annual payment amount for a given year level and MMM classification
    /// - Parameters:
    ///   - yearLevel: Year level (1-4, capped at 4)
    ///   - mmmClassification: Predominant MMM classification (3-7)
    ///   - registrationStatus: Doctor's registration status
    /// - Returns: Annual payment amount in AUD
    public static func getAnnualPayment(
        yearLevel: Int,
        mmmClassification: Int,
        registrationStatus: RegistrationStatus
    ) -> Double {
        let cappedYearLevel = min(4, max(1, yearLevel))
        let baseAmount = paymentMatrixVR[cappedYearLevel]?[mmmClassification] ?? 0

        if registrationStatus.qualifiesForFullRate {
            return baseAmount
        } else {
            return baseAmount * nonVocationalMultiplier
        }
    }

    /// Calculates the year level based on payment history
    /// - Parameters:
    ///   - paymentsReceived: Number of WIP payments previously received
    ///   - isNewParticipant: Whether this is a new participant
    ///   - predominantMMM: Predominant MMM classification for initial level
    /// - Returns: Current year level (1-4)
    public static func calculateYearLevel(
        paymentsReceived: Int,
        isNewParticipant: Bool,
        predominantMMM: Int
    ) -> Int {
        if isNewParticipant {
            // New participants in MMM 3-5 start at year 2
            let initialLevel = (3...5).contains(predominantMMM) ? 2 : 1
            return initialLevel
        }

        // Continuing participants progress based on payments received
        switch paymentsReceived {
        case 0: return 1
        case 1: return 2
        case 2: return 3
        default: return 4
        }
    }

    /// Checks eligibility for payment based on active quarters
    /// - Parameters:
    ///   - activeQuartersInPeriod: Number of active quarters in the reference period
    ///   - isNewParticipant: Whether this is a new participant
    ///   - predominantMMM: Predominant MMM classification
    /// - Returns: Eligibility result with details
    public static func checkEligibility(
        activeQuartersInPeriod: Int,
        isNewParticipant: Bool,
        predominantMMM: Int
    ) -> EligibilityResult {
        let requiredQuarters: Int
        let referencePeriod: Int

        if isNewParticipant {
            if (3...5).contains(predominantMMM) {
                requiredQuarters = newParticipantMMM35RequiredQuarters
                referencePeriod = newParticipantMMM35ReferencePeriod
            } else {
                requiredQuarters = newParticipantMMM67RequiredQuarters
                referencePeriod = newParticipantMMM67ReferencePeriod
            }
        } else {
            requiredQuarters = continuingRequiredQuarters
            referencePeriod = continuingReferencePeriod
        }

        let isEligible = activeQuartersInPeriod >= requiredQuarters
        let quartersNeeded = max(0, requiredQuarters - activeQuartersInPeriod)

        return EligibilityResult(
            isEligible: isEligible,
            activeQuarters: activeQuartersInPeriod,
            requiredQuarters: requiredQuarters,
            referencePeriodQuarters: referencePeriod,
            quartersNeeded: quartersNeeded
        )
    }

    /// Validates session counts for a day
    /// - Parameter sessionsOnDate: Number of sessions recorded for a single date
    /// - Returns: Number of valid sessions (capped at 2)
    public static func validSessionsForDay(_ sessionsOnDate: Int) -> Int {
        min(sessionsOnDate, maximumSessionsPerDay)
    }

    /// Calculates counted sessions for a quarter (capped at 104)
    /// - Parameter rawSessions: Total sessions before capping
    /// - Returns: Counted sessions for quota purposes
    public static func countedSessionsForQuarter(_ rawSessions: Int) -> Int {
        min(rawSessions, quarterlyMaximumSessions)
    }

    /// Checks if a quarter is active (meets minimum sessions)
    /// - Parameter sessions: Number of valid sessions in the quarter
    /// - Returns: True if quarter is active (>=21 sessions)
    public static func isActiveQuarter(sessions: Int) -> Bool {
        sessions >= quarterlyMinimumSessions
    }

    // MARK: - MMM Classification Descriptions

    /// Returns a human-readable description for an MMM classification
    /// - Parameter classification: MMM classification (1-7)
    /// - Returns: Description string (e.g., "Large rural" for MMM 3)
    public static func mmmDescription(_ classification: Int) -> String {
        switch classification {
        case 1: return "Metropolitan"
        case 2: return "Regional"
        case 3: return "Large rural"
        case 4: return "Medium rural"
        case 5: return "Small rural"
        case 6: return "Remote"
        case 7: return "Very remote"
        default: return ""
        }
    }

    /// Returns a short description for eligible MMM classifications (3-7 only)
    /// - Parameter classification: MMM classification
    /// - Returns: Short description or empty string if not eligible
    public static func eligibleMMMDescription(_ classification: Int) -> String {
        guard isEligible(mmmClassification: classification) else { return "" }
        return mmmDescription(classification)
    }
}

// MARK: - Supporting Types

/// Result of eligibility check
public struct EligibilityResult: Codable, Sendable {
    public let isEligible: Bool
    public let activeQuarters: Int
    public let requiredQuarters: Int
    public let referencePeriodQuarters: Int
    public let quartersNeeded: Int

    public init(
        isEligible: Bool,
        activeQuarters: Int,
        requiredQuarters: Int,
        referencePeriodQuarters: Int,
        quartersNeeded: Int
    ) {
        self.isEligible = isEligible
        self.activeQuarters = activeQuarters
        self.requiredQuarters = requiredQuarters
        self.referencePeriodQuarters = referencePeriodQuarters
        self.quartersNeeded = quartersNeeded
    }

    public var progressDescription: String {
        if isEligible {
            return "Eligible for payment"
        } else {
            return "\(quartersNeeded) more active quarter\(quartersNeeded == 1 ? "" : "s") needed"
        }
    }
}

/// Session validation result
public struct SessionValidation: Codable, Sendable {
    public let isValid: Bool
    public let durationHours: Double
    public let mmmClassification: Int
    public let validationErrors: [String]

    public init(
        isValid: Bool,
        durationHours: Double,
        mmmClassification: Int,
        validationErrors: [String]
    ) {
        self.isValid = isValid
        self.durationHours = durationHours
        self.mmmClassification = mmmClassification
        self.validationErrors = validationErrors
    }

    /// Creates a validation result for a session
    public static func validate(
        durationHours: Double,
        mmmClassification: Int
    ) -> SessionValidation {
        var errors: [String] = []

        if durationHours < RuralSubsidyService.minimumSessionHours {
            errors.append("Session must be at least 3 hours (was \(String(format: "%.1f", durationHours)) hours)")
        }

        if !RuralSubsidyService.isEligible(mmmClassification: mmmClassification) {
            errors.append("Location must be MMM 3-7 (was MMM\(mmmClassification))")
        }

        return SessionValidation(
            isValid: errors.isEmpty,
            durationHours: durationHours,
            mmmClassification: mmmClassification,
            validationErrors: errors
        )
    }
}

/// Payment calculation result
public struct PaymentCalculation: Codable, Sendable {
    public let isEligible: Bool
    public let paymentAmount: Double
    public let yearLevel: Int
    public let predominantMMM: Int
    public let registrationStatus: RegistrationStatus
    public let multiplier: Double
    public let activeQuarters: Int
    public let reason: String?

    public init(
        isEligible: Bool,
        paymentAmount: Double,
        yearLevel: Int,
        predominantMMM: Int,
        registrationStatus: RegistrationStatus,
        multiplier: Double,
        activeQuarters: Int,
        reason: String?
    ) {
        self.isEligible = isEligible
        self.paymentAmount = paymentAmount
        self.yearLevel = yearLevel
        self.predominantMMM = predominantMMM
        self.registrationStatus = registrationStatus
        self.multiplier = multiplier
        self.activeQuarters = activeQuarters
        self.reason = reason
    }
}
