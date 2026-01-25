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
import SwiftData

/// Categories of expenses for tax purposes
public enum ExpenseCategory: String, CaseIterable, Codable {
    case travel = "travel"
    case accommodation = "accommodation"
    case meals = "meals"
    case supplies = "supplies"
    case professional = "professional"
    case insurance = "insurance"
    case training = "training"
    case other = "other"

    public var description: String {
        switch self {
        case .travel: return "Travel"
        case .accommodation: return "Accommodation"
        case .meals: return "Meals"
        case .supplies: return "Medical Supplies"
        case .professional: return "Professional Development"
        case .insurance: return "Insurance"
        case .training: return "Training"
        case .other: return "Other"
        }
    }

    /// Whether this category is typically tax deductible
    public var isTaxDeductible: Bool {
        switch self {
        case .travel, .accommodation, .meals, .supplies, .professional, .insurance, .training:
            return true
        case .other:
            return false
        }
    }
}

/// Represents expense receipts for reimbursement and tax purposes
///
/// Attachments are stored separately in the `Attachment` model and linked by `receiptId`.
/// Use a FetchDescriptor with predicate `$0.receiptId == receipt.id` to query attachments.
@Model
public final class Receipt {
    public var id: UUID = UUID()
    public var dailyRecordId: UUID?
    public var assignmentId: UUID?
    public var amount: Double = 0
    public var category: ExpenseCategory = ExpenseCategory.other

    /// Legacy single image data - kept for backwards compatibility during migration
    /// Use `Attachment` model with `receiptId` for new code
    @available(*, deprecated, message: "Use Attachment model with receiptId instead")
    public var imageData: Data?

    public var date: Date = Date()
    public var receiptDescription: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        amount: Double,
        category: ExpenseCategory,
        date: Date,
        receiptDescription: String,
        dailyRecordId: UUID? = nil,
        assignmentId: UUID? = nil,
        imageData: Data? = nil
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.date = date
        self.receiptDescription = receiptDescription
        self.dailyRecordId = dailyRecordId
        self.assignmentId = assignmentId
        self.imageData = imageData
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Whether this receipt has legacy image data (for backwards compatibility check)
    /// Note: Use ModelContext to query Attachment model for full attachment check
    public var hasImage: Bool {
        imageData != nil
    }
}
