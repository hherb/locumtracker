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

/// Maximum file size for attachments in bytes (10 MB)
public let maxAttachmentSize: Int = 10 * 1024 * 1024

/// Supported attachment file types for documents shared to LocumTracker
public enum AttachmentType: String, CaseIterable, Codable {
    case pdf = "pdf"
    case wordDoc = "doc"
    case wordDocx = "docx"
    case jpeg = "jpeg"
    case png = "png"
    case heic = "heic"
    case email = "eml"
    case other = "other"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .pdf: return "PDF Document"
        case .wordDoc, .wordDocx: return "Word Document"
        case .jpeg, .png, .heic: return "Image"
        case .email: return "Email"
        case .other: return "Document"
        }
    }

    /// SF Symbol name for display
    public var systemImage: String {
        switch self {
        case .pdf: return "doc.fill"
        case .wordDoc, .wordDocx: return "doc.text.fill"
        case .jpeg, .png, .heic: return "photo.fill"
        case .email: return "envelope.fill"
        case .other: return "doc.fill"
        }
    }

    /// Whether this type is an image
    public var isImage: Bool {
        switch self {
        case .jpeg, .png, .heic: return true
        default: return false
        }
    }

    /// UTType identifiers for NSExtensionActivationRule
    public static var supportedUTTypes: [String] {
        [
            "com.adobe.pdf",
            "com.microsoft.word.doc",
            "org.openxmlformats.wordprocessingml.document",
            "public.jpeg",
            "public.png",
            "public.heic",
            "com.apple.mail.email"
        ]
    }

    /// Initialize from file extension
    public init(fromExtension ext: String) {
        switch ext.lowercased() {
        case "pdf": self = .pdf
        case "doc": self = .wordDoc
        case "docx": self = .wordDocx
        case "jpg", "jpeg": self = .jpeg
        case "png": self = .png
        case "heic", "heif": self = .heic
        case "eml": self = .email
        default: self = .other
        }
    }

    /// Infer attachment type from filename
    /// - Parameter filename: The filename or path to check
    /// - Returns: The matching attachment type, or nil if unknown
    public static func from(filename: String) -> AttachmentType? {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return .pdf
        case "doc": return .wordDoc
        case "docx": return .wordDocx
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic", "heif": return .heic
        case "eml": return .email
        default: return nil
        }
    }
}

/// File attachment linked to an Assignment or Receipt
///
/// Attachments allow users to associate documents (contracts, agreements, receipts, etc.)
/// with their assignments or expense receipts via the iOS Share Extension.
@Model
public final class Attachment {
    public var id: UUID = UUID()

    /// Link to Assignment (mutually exclusive with receiptId)
    public var assignmentId: UUID?

    /// Link to Receipt (mutually exclusive with assignmentId)
    public var receiptId: UUID?

    /// Original filename
    public var filename: String = ""

    /// File type determined from extension or MIME type
    public var fileType: AttachmentType = AttachmentType.other

    /// File size in bytes
    public var fileSize: Int64 = 0

    /// The actual file data
    public var fileData: Data?

    /// Optional notes/description added by user
    public var notes: String?

    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        assignmentId: UUID? = nil,
        receiptId: UUID? = nil,
        filename: String,
        fileType: AttachmentType,
        fileSize: Int64,
        fileData: Data?,
        notes: String? = nil
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.receiptId = receiptId
        self.filename = filename
        self.fileType = fileType
        self.fileSize = fileSize
        self.fileData = fileData
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Human-readable file size (e.g., "1.2 MB")
    public var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Whether this attachment has file data loaded
    public var hasData: Bool {
        fileData != nil
    }
}
