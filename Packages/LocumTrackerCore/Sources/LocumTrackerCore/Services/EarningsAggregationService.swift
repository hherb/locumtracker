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

/// Time period options for filtering earnings data
///
/// Used for filtering records and calculations in earnings views.
public enum EarningsPeriod: String, CaseIterable, Sendable {
    case week = "This Week"
    case month = "This Month"
    case quarter = "This Quarter"
    case year = "This Year"
    case all = "All Time"

    /// Returns the start date for this period
    /// - Parameter referenceDate: The reference date (defaults to current date)
    /// - Returns: The start date of the period
    public func startDate(from referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: referenceDate) ?? referenceDate
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: referenceDate) ?? referenceDate
        case .all:
            return Date.distantPast
        }
    }
}

/// Service providing earnings aggregation and calculation functions
///
/// Contains pure functions for calculating percentages, rates, and net earnings.
public struct EarningsAggregationService {

    // MARK: - Percentage Calculations

    /// Calculates the percentage of earnings relative to a total
    /// - Parameters:
    ///   - earnings: The portion of earnings
    ///   - total: The total earnings
    /// - Returns: Percentage value (0-100), or 0 if total is zero
    public static func percentage(earnings: Double, total: Double) -> Double {
        guard total > 0 else { return 0.0 }
        return (earnings / total) * 100.0
    }

    // MARK: - Rate Calculations

    /// Calculates the effective hourly rate
    /// - Parameters:
    ///   - earnings: Total earnings
    ///   - hours: Total hours worked
    /// - Returns: Hourly rate, or 0 if hours is zero
    public static func effectiveHourlyRate(earnings: Double, hours: Double) -> Double {
        guard hours > 0 else { return 0.0 }
        return earnings / hours
    }

    // MARK: - Net Earnings

    /// Calculates net earnings after expenses
    /// - Parameters:
    ///   - total: Total gross earnings
    ///   - expenses: Total expenses
    /// - Returns: Net earnings (may be negative if expenses exceed earnings)
    public static func netEarnings(total: Double, expenses: Double) -> Double {
        return total - expenses
    }

    // MARK: - Summation

    /// Sums an array of earnings values
    /// - Parameter values: Array of earnings amounts
    /// - Returns: Total sum of all values
    public static func sumEarnings(_ values: [Double]) -> Double {
        values.reduce(0, +)
    }

    /// Sums earnings from an array using a key path
    /// - Parameters:
    ///   - items: Array of items to sum
    ///   - keyPath: Key path to the earnings value on each item
    /// - Returns: Total sum
    public static func sumEarnings<T>(_ items: [T], keyPath: KeyPath<T, Double>) -> Double {
        items.reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    /// Sums optional earnings from an array using a key path
    /// - Parameters:
    ///   - items: Array of items to sum
    ///   - keyPath: Key path to the optional earnings value on each item
    /// - Returns: Total sum (nil values are treated as 0)
    public static func sumOptionalEarnings<T>(_ items: [T], keyPath: KeyPath<T, Double?>) -> Double {
        items.compactMap { $0[keyPath: keyPath] }.reduce(0, +)
    }
}
