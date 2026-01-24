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
import SwiftUI
import LocumTrackerCore

/// LocumTrackerUI module
/// Provides shared SwiftUI components for iOS and macOS apps
public enum LocumTrackerUI {
    /// Module version
    public static let version = "1.0.0"
}

/// Currency formatting helper
public struct CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "AUD"
        return f
    }()

    /// Formats a Double amount as Australian currency
    /// - Parameter amount: The amount to format
    /// - Returns: Formatted currency string (e.g., "$150.00")
    public static func format(_ amount: Double) -> String {
        formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Expense Category Helpers

/// Provides UI-related properties for ExpenseCategory
public extension ExpenseCategory {
    /// SF Symbol icon name for this category
    var iconName: String {
        switch self {
        case .travel: return "car"
        case .accommodation: return "bed.double"
        case .meals: return "fork.knife"
        case .supplies: return "cross.case"
        case .professional: return "briefcase"
        case .insurance: return "shield"
        case .training: return "book"
        case .other: return "ellipsis.circle"
        }
    }

    /// Color associated with this category for UI display
    var color: Color {
        switch self {
        case .travel: return .blue
        case .accommodation: return .purple
        case .meals: return .orange
        case .supplies: return .red
        case .professional: return .teal
        case .insurance: return .green
        case .training: return .indigo
        case .other: return .gray
        }
    }
}

// MARK: - Session Template Constants

/// Default values for session template creation
public enum SessionTemplateDefaults {
    /// Default start hour for new session templates (8 AM)
    public static let defaultStartHour = 8
    /// Default end hour for new session templates (12 PM)
    public static let defaultEndHour = 12
}

/// Time conversion constants
public enum TimeConstants {
    /// Number of seconds in one hour
    public static let secondsPerHour = 3600
    /// Number of seconds in one minute
    public static let secondsPerMinute = 60
}

// MARK: - MMM Classification Helpers

/// Provides UI colors for Modified Monash Model classifications
public enum MMMColors {
    /// Returns the color associated with an MMM classification level
    /// - Parameter classification: The MMM classification (1-7)
    /// - Returns: A Color appropriate for the classification
    public static func color(for classification: Int) -> Color {
        switch classification {
        case 1, 2: return .gray      // Metropolitan/Regional - not eligible
        case 3: return .blue         // Large rural town
        case 4: return .cyan         // Medium rural town
        case 5: return .teal         // Small rural town
        case 6: return .orange       // Remote community
        case 7: return .red          // Very remote community
        default: return .gray
        }
    }
}
