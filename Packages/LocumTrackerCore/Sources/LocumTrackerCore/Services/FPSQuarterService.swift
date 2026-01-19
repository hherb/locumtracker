import Foundation

/// Service providing quarter-related calculations for FPS (Flexible Payment System) tracking
///
/// This service contains pure functions for calculating quarter identifiers, session counts,
/// and progress tracking for the WIP Doctor Stream Flexible Payment System.
public struct FPSQuarterService {

    // MARK: - Quarter Identification

    /// Generates a human-readable quarter string (e.g., "2026 Q1")
    /// - Parameter date: The date to get the quarter string for
    /// - Returns: Quarter string in format "YYYY QN"
    public static func quarterString(for date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let quarter = (month - 1) / 3 + 1
        let year = calendar.component(.year, from: date)
        return "\(year) Q\(quarter)"
    }

    /// Generates a quarter identifier for sorting/grouping (e.g., "2026-Q1")
    /// - Parameter date: The date to get the quarter identifier for
    /// - Returns: Quarter identifier in format "YYYY-QN"
    public static func quarterIdentifier(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let quarter = (month - 1) / 3 + 1
        return "\(year)-Q\(quarter)"
    }

    /// Extracts the quarter number (1-4) from a date
    /// - Parameter date: The date to extract the quarter from
    /// - Returns: Quarter number (1 for Jan-Mar, 2 for Apr-Jun, 3 for Jul-Sep, 4 for Oct-Dec)
    public static func quarterNumber(for date: Date) -> Int {
        let month = Calendar.current.component(.month, from: date)
        return (month - 1) / 3 + 1
    }

    // MARK: - Days Remaining

    /// Calculates the number of days remaining in the quarter
    /// - Parameter date: The reference date
    /// - Returns: Number of days remaining until end of quarter (0 if at end)
    public static func daysRemaining(from date: Date) -> Int {
        let calendar = Calendar.current
        guard let quarterInterval = calendar.dateInterval(of: .quarter, for: date) else {
            return 0
        }
        let components = calendar.dateComponents([.day], from: date, to: quarterInterval.end)
        return max(0, components.day ?? 0)
    }

    // MARK: - Session Counting

    /// Counts total sessions applying the FPS 2-per-day limit
    ///
    /// FPS rules only count a maximum of 2 sessions per day, regardless of how many
    /// were actually worked.
    ///
    /// - Parameter sessionsPerDay: Dictionary mapping dates to session counts
    /// - Returns: Total session count with per-day limit applied
    public static func countSessions(_ sessionsPerDay: [Date: Int]) -> Int {
        sessionsPerDay.values.reduce(0) { sum, count in
            sum + min(count, RuralSubsidyService.maximumSessionsPerDay)
        }
    }

    /// Counts days that exceed the FPS 2-session limit
    /// - Parameter sessionsPerDay: Dictionary mapping dates to session counts
    /// - Returns: Number of days with more than 2 sessions
    public static func daysExceedingLimit(_ sessionsPerDay: [Date: Int]) -> Int {
        sessionsPerDay.values.filter { $0 > RuralSubsidyService.maximumSessionsPerDay }.count
    }

    /// Finds the predominant (most common) MMM classification
    /// - Parameter counts: Dictionary mapping MMM classification to count
    /// - Returns: The MMM classification with the highest count, or 0 if empty
    public static func predominantMMM(from counts: [Int: Int]) -> Int {
        counts.max { $0.value < $1.value }?.key ?? 0
    }

    // MARK: - Progress Calculation

    /// Calculates progress percentage toward the 21-session quarterly minimum
    /// - Parameter sessions: Number of counted sessions
    /// - Returns: Percentage as a value from 0 to 100 (capped at 100)
    public static func progressPercentage(sessions: Int) -> Double {
        min(100.0, Double(sessions) / Double(QuarterlyQuota.minimumSessions) * 100)
    }

    /// Determines the appropriate progress color based on percentage and quota status
    ///
    /// Color coding:
    /// - Green: Quota met (21+ sessions)
    /// - Blue: 75-99% progress
    /// - Orange: 50-74% progress
    /// - Red: Under 50% progress
    ///
    /// - Parameters:
    ///   - percentage: Progress percentage (0-100)
    ///   - quotaMet: Whether the 21-session quota has been met
    /// - Returns: Color name as a string ("green", "blue", "orange", or "red")
    public static func progressColorName(percentage: Double, quotaMet: Bool) -> String {
        if quotaMet {
            return "green"
        } else if percentage >= 75 {
            return "blue"
        } else if percentage >= 50 {
            return "orange"
        } else {
            return "red"
        }
    }

    // MARK: - Quarter Start Date

    /// Gets the start date of the quarter containing the given date
    /// - Parameter date: Any date within the quarter
    /// - Returns: The first day of that quarter
    public static func quarterStartDate(for date: Date) -> Date {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .quarter, for: date) else {
            return date
        }
        return interval.start
    }

    // MARK: - Session Counting for Quarter

    /// Counts valid sessions for a quarter, applying both per-day and quarterly caps
    ///
    /// This applies the FPS rules:
    /// 1. Maximum 2 sessions per day counted
    /// 2. Maximum 104 sessions per quarter counted
    ///
    /// - Parameter sessionsPerDay: Dictionary mapping dates to session counts for the quarter
    /// - Returns: Total counted sessions (capped at 104)
    public static func countSessionsForQuarter(_ sessionsPerDay: [Date: Int]) -> Int {
        let totalWithDayLimit = countSessions(sessionsPerDay)
        return RuralSubsidyService.countedSessionsForQuarter(totalWithDayLimit)
    }
}
