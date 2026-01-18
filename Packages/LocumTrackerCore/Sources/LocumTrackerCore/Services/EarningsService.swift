import Foundation

/// Handles earnings calculations for assignments
public struct EarningsService {

    /// Default on-call rate as percentage of regular rate (25%)
    public static let defaultOnCallPercentage: Double = 0.25

    /// Default call-out rate as percentage of regular rate (50%)
    public static let defaultCallOutPercentage: Double = 0.50

    /// Calculates earnings for a daily rate assignment
    /// - Parameters:
    ///   - dailyRate: Fixed daily rate
    ///   - daysWorked: Number of days worked
    /// - Returns: Total earnings
    public static func calculateDailyRateEarnings(dailyRate: Double, daysWorked: Int) -> Double {
        dailyRate * Double(daysWorked)
    }

    /// Calculates earnings for an hourly rate session
    /// - Parameters:
    ///   - hourlyRate: Hourly rate
    ///   - hoursWorked: Number of hours worked
    /// - Returns: Total earnings
    public static func calculateHourlyEarnings(hourlyRate: Double, hoursWorked: Double) -> Double {
        hourlyRate * hoursWorked
    }

    /// Calculates on-call earnings
    /// - Parameters:
    ///   - baseHourlyRate: Base hourly rate
    ///   - onCallRate: Optional explicit on-call rate (uses default percentage if nil)
    ///   - hours: Number of on-call hours
    /// - Returns: On-call earnings
    public static func calculateOnCallEarnings(
        baseHourlyRate: Double,
        onCallRate: Double?,
        hours: Double
    ) -> Double {
        let rate = onCallRate ?? (baseHourlyRate * defaultOnCallPercentage)
        return rate * hours
    }

    /// Calculates call-out earnings
    /// - Parameters:
    ///   - callOutRate: Rate per call-out occurrence
    ///   - occurrences: Number of call-outs
    /// - Returns: Call-out earnings
    public static func calculateCallOutEarnings(callOutRate: Double, occurrences: Int) -> Double {
        callOutRate * Double(occurrences)
    }
}
