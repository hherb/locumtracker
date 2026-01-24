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

/// Supported attachment file types for receipts
public enum AttachmentType: String, CaseIterable, Codable {
    case jpeg = "jpeg"
    case png = "png"
    case heic = "heic"
    case pdf = "pdf"

    /// Human-readable description of the file type
    public var description: String {
        switch self {
        case .jpeg: return "JPEG Image"
        case .png: return "PNG Image"
        case .heic: return "HEIC Image"
        case .pdf: return "PDF Document"
        }
    }

    /// File extension for this type
    public var fileExtension: String {
        rawValue
    }

    /// MIME type for this attachment type
    public var mimeType: String {
        switch self {
        case .jpeg: return "image/jpeg"
        case .png: return "image/png"
        case .heic: return "image/heic"
        case .pdf: return "application/pdf"
        }
    }

    /// Whether this is an image type (vs document)
    public var isImage: Bool {
        switch self {
        case .jpeg, .png, .heic: return true
        case .pdf: return false
        }
    }

    /// Infer attachment type from file extension
    /// - Parameter filename: The filename or path to check
    /// - Returns: The matching attachment type, or nil if unknown
    public static func from(filename: String) -> AttachmentType? {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic", "heif": return .heic
        case "pdf": return .pdf
        default: return nil
        }
    }

    /// Infer attachment type from MIME type
    /// - Parameter mimeType: The MIME type string
    /// - Returns: The matching attachment type, or nil if unknown
    public static func from(mimeType: String) -> AttachmentType? {
        let normalized = mimeType.lowercased()
        switch normalized {
        case "image/jpeg", "image/jpg": return .jpeg
        case "image/png": return .png
        case "image/heic", "image/heif": return .heic
        case "application/pdf": return .pdf
        default: return nil
        }
    }
}

/// Maximum file size for attachments in bytes (10 MB)
public let maxAttachmentSize: Int = 10 * 1024 * 1024

/// Represents a file attachment for a receipt (image or document)
///
/// Attachments are stored as binary data and automatically synced via CloudKit.
/// Each receipt can have multiple attachments, ordered by their `order` property.
@Model
public final class ReceiptAttachment {
    /// Unique identifier for this attachment
    public var id: UUID = UUID()

    /// The receipt this attachment belongs to
    @Relationship(inverse: \Receipt.attachments)
    public var receipt: Receipt?

    /// Binary data of the attachment file
    public var data: Data = Data()

    /// Type of the attachment (image or PDF)
    public var attachmentType: AttachmentType = AttachmentType.jpeg

    /// Original filename if available
    public var filename: String?

    /// Display order within the receipt's attachments (0-based)
    public var order: Int = 0

    /// File size in bytes
    public var fileSize: Int = 0

    /// When the attachment was created
    public var createdAt: Date = Date()

    /// When the attachment was last updated
    public var updatedAt: Date = Date()

    /// Creates a new receipt attachment
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - data: Binary data of the attachment
    ///   - attachmentType: Type of file (image or PDF)
    ///   - filename: Original filename if available
    ///   - order: Display order within the receipt
    public init(
        id: UUID = UUID(),
        data: Data,
        attachmentType: AttachmentType,
        filename: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.data = data
        self.attachmentType = attachmentType
        self.filename = filename
        self.order = order
        self.fileSize = data.count
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Whether this attachment is an image (vs a document like PDF)
    public var isImage: Bool {
        attachmentType.isImage
    }

    /// Human-readable file size string (e.g., "1.2 MB")
    public var fileSizeDescription: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }

    /// Validates the attachment data
    /// - Returns: True if the attachment is valid
    public var isValid: Bool {
        !data.isEmpty && fileSize <= maxAttachmentSize
    }
}
