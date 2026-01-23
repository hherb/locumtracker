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

/// Extracted receipt data from OCR processing.
///
/// Contains structured information parsed from receipt text,
/// including merchant name, amounts, date, and the raw OCR text.
public struct ReceiptData: Sendable {
    /// The merchant or store name.
    public var merchant: String?

    /// The total amount on the receipt.
    public var totalAmount: Decimal?

    /// The subtotal before tax.
    public var subtotal: Decimal?

    /// The GST (Goods and Services Tax) amount.
    public var gstAmount: Decimal?

    /// The date on the receipt.
    public var date: Date?

    /// The raw OCR text, useful for debugging or manual review.
    public var rawText: String

    /// Average confidence score from OCR (0-1).
    public var confidence: Float

    /// Creates a new ReceiptData with raw text and confidence.
    ///
    /// - Parameters:
    ///   - rawText: The raw OCR text from all detected regions.
    ///   - confidence: The average confidence score (0-1).
    public init(rawText: String, confidence: Float) {
        self.rawText = rawText
        self.confidence = confidence
    }

    /// Creates a fully populated ReceiptData.
    ///
    /// - Parameters:
    ///   - merchant: The merchant or store name.
    ///   - totalAmount: The total amount.
    ///   - subtotal: The subtotal before tax.
    ///   - gstAmount: The GST amount.
    ///   - date: The receipt date.
    ///   - rawText: The raw OCR text.
    ///   - confidence: The average confidence score.
    public init(
        merchant: String? = nil,
        totalAmount: Decimal? = nil,
        subtotal: Decimal? = nil,
        gstAmount: Decimal? = nil,
        date: Date? = nil,
        rawText: String,
        confidence: Float
    ) {
        self.merchant = merchant
        self.totalAmount = totalAmount
        self.subtotal = subtotal
        self.gstAmount = gstAmount
        self.date = date
        self.rawText = rawText
        self.confidence = confidence
    }

    /// Whether any meaningful data was extracted.
    public var hasExtractedData: Bool {
        merchant != nil || totalAmount != nil || date != nil
    }

    /// The total amount as a Double for compatibility with Receipt model.
    public var totalAmountDouble: Double {
        guard let amount = totalAmount else { return 0 }
        return NSDecimalNumber(decimal: amount).doubleValue
    }
}

extension ReceiptData: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        if let merchant = merchant {
            parts.append("merchant: \(merchant)")
        }
        if let total = totalAmount {
            parts.append("total: $\(total)")
        }
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            parts.append("date: \(formatter.string(from: date))")
        }
        parts.append("confidence: \(String(format: "%.0f%%", confidence * 100))")
        return "ReceiptData(\(parts.joined(separator: ", ")))"
    }
}
