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
@Model
public final class Receipt {
    public var id: UUID = UUID()
    public var dailyRecordId: UUID?
    public var assignmentId: UUID?
    public var amount: Double = 0
    public var category: ExpenseCategory = ExpenseCategory.other

    /// Legacy single image data - kept for backwards compatibility during migration
    /// Use `attachments` for new code
    @available(*, deprecated, message: "Use attachments instead")
    public var imageData: Data?

    public var date: Date = Date()
    public var receiptDescription: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    /// File attachments (images and PDFs) associated with this receipt
    @Relationship(deleteRule: .cascade)
    public var attachments: [ReceiptAttachment]? = []

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
        self.attachments = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Whether this receipt has any attachments (images or documents)
    public var hasAttachments: Bool {
        if let attachments = attachments, !attachments.isEmpty {
            return true
        }
        // Backwards compatibility: check legacy imageData
        return imageData != nil
    }

    /// Whether this receipt has an associated image (legacy compatibility)
    public var hasImage: Bool {
        hasAttachments
    }

    /// All attachments sorted by order
    public var sortedAttachments: [ReceiptAttachment] {
        (attachments ?? []).sorted { $0.order < $1.order }
    }

    /// The primary (first) attachment, if any
    public var primaryAttachment: ReceiptAttachment? {
        sortedAttachments.first
    }

    /// Number of attachments
    public var attachmentCount: Int {
        (attachments?.count ?? 0) + (imageData != nil && (attachments?.isEmpty ?? true) ? 1 : 0)
    }

    /// Add an attachment to this receipt
    /// - Parameter attachment: The attachment to add
    public func addAttachment(_ attachment: ReceiptAttachment) {
        if attachments == nil {
            attachments = []
        }
        attachment.order = attachments?.count ?? 0
        attachment.receipt = self
        attachments?.append(attachment)
        updatedAt = Date()
    }

    /// Remove an attachment from this receipt
    /// - Parameter attachment: The attachment to remove
    public func removeAttachment(_ attachment: ReceiptAttachment) {
        attachments?.removeAll { $0.id == attachment.id }
        // Reorder remaining attachments
        for (index, att) in (attachments ?? []).enumerated() {
            att.order = index
        }
        updatedAt = Date()
    }

    /// Migrate legacy imageData to attachments
    /// Call this to convert old single-image receipts to the new attachment system
    public func migrateLegacyImage() {
        guard let data = imageData, !(attachments?.isEmpty == false) else { return }
        let attachment = ReceiptAttachment(
            data: data,
            attachmentType: .jpeg,
            filename: "receipt_image.jpg",
            order: 0
        )
        addAttachment(attachment)
        imageData = nil
    }
}
