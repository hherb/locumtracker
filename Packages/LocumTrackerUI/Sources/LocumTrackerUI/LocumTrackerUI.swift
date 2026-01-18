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

    public static func format(_ amount: Double) -> String {
        formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
