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
