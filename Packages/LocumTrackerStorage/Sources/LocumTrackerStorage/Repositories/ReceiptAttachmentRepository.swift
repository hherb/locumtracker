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

/// Repository for receipt-related Attachment operations
///
/// This repository provides convenience methods for querying attachments
/// associated with receipts. The `Attachment` model uses `receiptId` to
/// link attachments to receipts.
public final class ReceiptAttachmentRepository {
    public let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Find By ID

    /// Finds an attachment by its UUID
    /// - Parameter id: The attachment ID
    /// - Returns: Attachment if found
    public func findById(_ id: UUID) -> Attachment? {
        let predicate = #Predicate<Attachment> { $0.id == id }
        let descriptor = FetchDescriptor<Attachment>(predicate: predicate)
        return (try? modelContext.fetch(descriptor))?.first
    }

    // MARK: - Receipt Attachment Queries

    /// Fetches all attachments for a specific receipt
    /// - Parameter receiptId: The receipt's UUID
    /// - Returns: Array of attachments sorted by creation date
    public func fetchByReceipt(_ receiptId: UUID) -> [Attachment] {
        let predicate = #Predicate<Attachment> { $0.receiptId == receiptId }
        let descriptor = FetchDescriptor<Attachment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetches attachments by type for receipts
    /// - Parameter type: The attachment type to filter by
    /// - Returns: Array of attachments of that type
    public func fetchByType(_ type: AttachmentType) -> [Attachment] {
        // Filter in Swift since SwiftData predicates don't support enum comparisons well
        let predicate = #Predicate<Attachment> { $0.receiptId != nil }
        let descriptor = FetchDescriptor<Attachment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.fileType == type }
    }

    /// Fetches all image attachments for receipts (JPEG, PNG, HEIC)
    /// - Returns: Array of image attachments
    public func fetchImages() -> [Attachment] {
        // Filter in Swift since SwiftData predicates don't support complex enum comparisons
        let predicate = #Predicate<Attachment> { $0.receiptId != nil }
        let descriptor = FetchDescriptor<Attachment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.fileType.isImage }
    }

    /// Fetches all PDF attachments for receipts
    /// - Returns: Array of PDF attachments
    public func fetchPDFs() -> [Attachment] {
        // Filter in Swift since SwiftData predicates don't support enum comparisons well
        let predicate = #Predicate<Attachment> { $0.receiptId != nil }
        let descriptor = FetchDescriptor<Attachment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.fileType == .pdf }
    }

    /// Fetches receipt attachments within a date range
    /// - Parameters:
    ///   - startDate: Start of range (inclusive)
    ///   - endDate: End of range (inclusive)
    /// - Returns: Array of attachments sorted by creation date (newest first)
    public func fetchByDateRange(startDate: Date, endDate: Date) -> [Attachment] {
        let predicate = #Predicate<Attachment> {
            $0.receiptId != nil &&
            $0.createdAt >= startDate && $0.createdAt <= endDate
        }
        let descriptor = FetchDescriptor<Attachment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Calculates total storage used by receipt attachments
    /// - Returns: Total file size in bytes
    public func totalStorageUsed() -> Int64 {
        let predicate = #Predicate<Attachment> { $0.receiptId != nil }
        let descriptor = FetchDescriptor<Attachment>(predicate: predicate)
        let attachments = (try? modelContext.fetch(descriptor)) ?? []
        return attachments.reduce(0) { $0 + $1.fileSize }
    }

    /// Calculates storage used by attachments for a specific receipt
    /// - Parameter receiptId: The receipt's UUID
    /// - Returns: Total file size in bytes for that receipt's attachments
    public func storageUsedByReceipt(_ receiptId: UUID) -> Int64 {
        let attachments = fetchByReceipt(receiptId)
        return attachments.reduce(0) { $0 + $1.fileSize }
    }

    /// Counts attachments for a specific receipt
    /// - Parameter receiptId: The receipt's UUID
    /// - Returns: Number of attachments
    public func countByReceipt(_ receiptId: UUID) -> Int {
        let predicate = #Predicate<Attachment> { $0.receiptId == receiptId }
        let descriptor = FetchDescriptor<Attachment>(predicate: predicate)
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - CRUD Operations

    /// Saves an attachment to the context
    /// - Parameter attachment: The attachment to save
    public func save(_ attachment: Attachment) {
        modelContext.insert(attachment)
    }

    /// Deletes an attachment
    /// - Parameter attachment: The attachment to delete
    public func delete(_ attachment: Attachment) {
        modelContext.delete(attachment)
    }

    /// Deletes all attachments for a receipt
    /// - Parameter receiptId: The receipt's UUID
    public func deleteAllForReceipt(_ receiptId: UUID) {
        let attachments = fetchByReceipt(receiptId)
        for attachment in attachments {
            modelContext.delete(attachment)
        }
    }
}
