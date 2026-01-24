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
import LocumTrackerCore

/// Repository for ReceiptAttachment model CRUD operations
public final class ReceiptAttachmentRepository: Repository {
    public typealias Model = ReceiptAttachment

    public let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Find By ID

    /// Finds an attachment by its UUID
    /// - Parameter id: The attachment ID
    /// - Returns: Attachment if found
    public func findById(_ id: UUID) -> ReceiptAttachment? {
        let predicate = #Predicate<ReceiptAttachment> { $0.id == id }
        return fetch(predicate: predicate, sortDescriptors: [], fetchLimit: 1).first
    }

    // MARK: - Specialized Queries

    /// Fetches all attachments for a specific receipt
    /// - Parameter receiptId: The receipt's UUID
    /// - Returns: Array of attachments ordered by their order property
    public func fetchByReceipt(_ receiptId: UUID) -> [ReceiptAttachment] {
        let predicate = #Predicate<ReceiptAttachment> { $0.receipt?.id == receiptId }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.order, order: .forward)]
        )
    }

    /// Fetches attachments by type (e.g., only PDFs or only images)
    /// - Parameter type: The attachment type to filter by
    /// - Returns: Array of attachments of that type
    public func fetchByType(_ type: AttachmentType) -> [ReceiptAttachment] {
        let predicate = #Predicate<ReceiptAttachment> { $0.attachmentType == type }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// Fetches all image attachments (JPEG, PNG, HEIC)
    /// - Returns: Array of image attachments
    public func fetchImages() -> [ReceiptAttachment] {
        // Use individual type checks since isImage is computed
        let predicate = #Predicate<ReceiptAttachment> {
            $0.attachmentType == .jpeg ||
            $0.attachmentType == .png ||
            $0.attachmentType == .heic
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// Fetches all PDF attachments
    /// - Returns: Array of PDF attachments
    public func fetchPDFs() -> [ReceiptAttachment] {
        let predicate = #Predicate<ReceiptAttachment> { $0.attachmentType == .pdf }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// Fetches attachments within a date range
    /// - Parameters:
    ///   - startDate: Start of range (inclusive)
    ///   - endDate: End of range (inclusive)
    /// - Returns: Array of attachments sorted by creation date (newest first)
    public func fetchByDateRange(startDate: Date, endDate: Date) -> [ReceiptAttachment] {
        let predicate = #Predicate<ReceiptAttachment> {
            $0.createdAt >= startDate && $0.createdAt <= endDate
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// Calculates total storage used by attachments
    /// - Returns: Total file size in bytes
    public func totalStorageUsed() -> Int {
        let attachments = fetchAll()
        return attachments.reduce(0) { $0 + $1.fileSize }
    }

    /// Calculates storage used by attachments for a specific receipt
    /// - Parameter receiptId: The receipt's UUID
    /// - Returns: Total file size in bytes for that receipt's attachments
    public func storageUsedByReceipt(_ receiptId: UUID) -> Int {
        let attachments = fetchByReceipt(receiptId)
        return attachments.reduce(0) { $0 + $1.fileSize }
    }
}
