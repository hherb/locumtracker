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

/// Processes pending attachments from the Share Extension
///
/// When the app becomes active, this processor reads any pending attachments
/// from the shared App Group container and creates the appropriate SwiftData
/// records (Attachment and optionally Receipt).
@MainActor
class PendingAttachmentProcessor {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Process all pending attachments from Share Extension
    ///
    /// - Returns: Number of attachments successfully processed
    @discardableResult
    func processAllPending() -> Int {
        let pending = SharedDataService.readPendingAttachments()
        var processedCount = 0

        for item in pending {
            do {
                try processPendingAttachment(item)
                try SharedDataService.clearPendingAttachment(item)
                processedCount += 1
            } catch {
                print("Failed to process pending attachment '\(item.filename)': \(error)")
            }
        }

        if processedCount > 0 {
            try? modelContext.save()
        }

        return processedCount
    }

    /// Process a single pending attachment
    private func processPendingAttachment(_ pending: PendingAttachment) throws {
        // Read file data from shared container
        guard let fileData = SharedDataService.readPendingFileData(
            filename: pending.fileDataFilename
        ) else {
            throw ProcessingError.fileDataNotFound(pending.fileDataFilename)
        }

        // Determine file type
        let fileType = AttachmentType(rawValue: pending.fileType) ?? .other

        switch pending.targetType {
        case .assignment:
            try processAssignmentAttachment(pending, fileData: fileData, fileType: fileType)

        case .newReceipt:
            try processNewReceiptAttachment(pending, fileData: fileData, fileType: fileType)
        }
    }

    /// Create attachment linked to an existing assignment
    private func processAssignmentAttachment(
        _ pending: PendingAttachment,
        fileData: Data,
        fileType: AttachmentType
    ) throws {
        guard let assignmentId = pending.targetId else {
            throw ProcessingError.missingTargetId
        }

        // Verify assignment exists
        let descriptor = FetchDescriptor<Assignment>(
            predicate: #Predicate { $0.id == assignmentId }
        )
        guard let _ = try modelContext.fetch(descriptor).first else {
            throw ProcessingError.assignmentNotFound(assignmentId)
        }

        // Create attachment
        let attachment = Attachment(
            assignmentId: assignmentId,
            filename: pending.filename,
            fileType: fileType,
            fileSize: Int64(fileData.count),
            fileData: fileData,
            notes: pending.notes
        )
        modelContext.insert(attachment)
    }

    /// Create a new receipt with attachment
    private func processNewReceiptAttachment(
        _ pending: PendingAttachment,
        fileData: Data,
        fileType: AttachmentType
    ) throws {
        // Create new receipt
        // For images, also store in receipt's imageData field for existing UI compatibility
        let receipt = Receipt(
            amount: 0,
            category: .other,
            date: pending.createdAt,
            receiptDescription: pending.filename,
            imageData: fileType.isImage ? fileData : nil
        )
        modelContext.insert(receipt)

        // Create attachment linked to receipt
        let attachment = Attachment(
            receiptId: receipt.id,
            filename: pending.filename,
            fileType: fileType,
            fileSize: Int64(fileData.count),
            fileData: fileData,
            notes: pending.notes
        )
        modelContext.insert(attachment)
    }

    // MARK: - Errors

    enum ProcessingError: Error, LocalizedError {
        case fileDataNotFound(String)
        case unsupportedFileType(String)
        case missingTargetId
        case assignmentNotFound(UUID)

        var errorDescription: String? {
            switch self {
            case .fileDataNotFound(let filename):
                return "File data not found for '\(filename)'"
            case .unsupportedFileType(let type):
                return "Unsupported file type: \(type)"
            case .missingTargetId:
                return "Missing target assignment ID"
            case .assignmentNotFound(let id):
                return "Assignment not found: \(id)"
            }
        }
    }
}
