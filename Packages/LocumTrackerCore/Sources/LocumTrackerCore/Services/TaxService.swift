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

/// Handles Australian tax calculations including GST and ABN validation
public struct TaxService {

    // MARK: - Constants

    /// Australian GST rate (10%)
    public static let gstRate: Double = 0.10

    /// Minimum invoice amount requiring customer ABN (B2B transactions)
    public static let customerABNThreshold: Double = 82.50

    // MARK: - GST Calculations

    /// Calculates GST for an amount
    /// - Parameters:
    ///   - amount: Pre-GST amount
    ///   - isGSTRegistered: Whether business is GST-registered
    /// - Returns: GST calculation result
    public static func calculateGST(amount: Double, isGSTRegistered: Bool) -> GSTCalculation {
        let gstAmount = isGSTRegistered ? amount * gstRate : 0.0
        return GSTCalculation(
            amount: amount,
            gstAmount: gstAmount,
            totalIncludingGST: amount + gstAmount,
            isGSTRegistered: isGSTRegistered
        )
    }

    /// Extracts the GST component from a GST-inclusive amount
    /// - Parameter gstInclusiveAmount: Amount including GST
    /// - Returns: The GST component
    public static func extractGST(from gstInclusiveAmount: Double) -> Double {
        gstInclusiveAmount - (gstInclusiveAmount / (1 + gstRate))
    }

    // MARK: - ABN Validation

    /// Validates an Australian Business Number using the official checksum algorithm
    /// Reference: https://abr.business.gov.au/Help/AbnFormat
    /// - Parameter abn: ABN string to validate (spaces and dashes allowed)
    /// - Returns: True if ABN passes checksum validation
    public static func validateABN(_ abn: String) -> Bool {
        // Remove spaces and dashes
        let clean = abn.filter { $0.isNumber }

        // Must be exactly 11 digits
        guard clean.count == 11 else { return false }

        // Convert to array of integers
        var digits = clean.compactMap { $0.wholeNumberValue }
        guard digits.count == 11 else { return false }

        // Step 1: Subtract 1 from the first digit
        digits[0] -= 1

        // Step 2: Multiply each digit by its weighting factor
        let weights = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19]
        var sum = 0
        for (index, digit) in digits.enumerated() {
            sum += digit * weights[index]
        }

        // Step 3: Sum must be divisible by 89
        return sum % 89 == 0
    }

    /// Formats an ABN with standard spacing (XX XXX XXX XXX)
    /// - Parameter abn: ABN string to format
    /// - Returns: Formatted ABN string
    public static func formatABN(_ abn: String) -> String {
        let clean = abn.filter { $0.isNumber }
        guard clean.count == 11 else { return abn }

        let chars = Array(clean)
        return "\(chars[0])\(chars[1]) \(chars[2])\(chars[3])\(chars[4]) \(chars[5])\(chars[6])\(chars[7]) \(chars[8])\(chars[9])\(chars[10])"
    }

    /// Determines if customer ABN is required on invoice
    /// - Parameter invoiceAmount: Total invoice amount
    /// - Returns: True if customer ABN is required for amounts >= $82.50
    public static func requiresCustomerABN(_ invoiceAmount: Double) -> Bool {
        invoiceAmount >= customerABNThreshold
    }
}

// MARK: - Supporting Types

/// Result of GST calculation
public struct GSTCalculation: Codable, Sendable {
    public let amount: Double
    public let gstAmount: Double
    public let totalIncludingGST: Double
    public let isGSTRegistered: Bool

    public init(amount: Double, gstAmount: Double, totalIncludingGST: Double, isGSTRegistered: Bool) {
        self.amount = amount
        self.gstAmount = gstAmount
        self.totalIncludingGST = totalIncludingGST
        self.isGSTRegistered = isGSTRegistered
    }
}
