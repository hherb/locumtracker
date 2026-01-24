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

// MARK: - Cached Assignment

/// Lightweight assignment info for Share Extension picker
///
/// This is a simplified representation of Assignment that can be safely
/// encoded/decoded for storage in the App Group container.
public struct CachedAssignment: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String?
    public let locationName: String
    public let startDate: Date
    public let endDate: Date
    public let status: String

    public init(
        id: UUID,
        name: String?,
        locationName: String,
        startDate: Date,
        endDate: Date,
        status: String
    ) {
        self.id = id
        self.name = name
        self.locationName = locationName
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
    }

    /// Display name combining assignment name and location
    public var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return locationName
    }

    /// Formatted date range for display
    public var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

// MARK: - Pending Attachment

/// Pending attachment waiting to be processed by main app
///
/// When the Share Extension saves a file, it creates a PendingAttachment
/// record and writes the file data to the shared container. The main app
/// processes these on foreground.
public struct PendingAttachment: Codable, Identifiable, Sendable {
    public let id: UUID
    public let targetType: TargetType
    public let targetId: UUID?
    public let filename: String
    public let fileType: String
    public let fileDataFilename: String
    public let notes: String?
    public let createdAt: Date

    public enum TargetType: String, Codable, Sendable {
        case assignment
        case newReceipt
    }

    public init(
        id: UUID = UUID(),
        targetType: TargetType,
        targetId: UUID?,
        filename: String,
        fileType: String,
        fileDataFilename: String,
        notes: String?
    ) {
        self.id = id
        self.targetType = targetType
        self.targetId = targetId
        self.filename = filename
        self.fileType = fileType
        self.fileDataFilename = fileDataFilename
        self.notes = notes
        self.createdAt = Date()
    }
}

// MARK: - Shared Data Service

/// Service for managing shared data between main app and Share Extension
///
/// Uses the App Group container for inter-process communication:
/// - Main app writes cached assignment list for extension picker
/// - Share Extension writes pending attachments for main app processing
/// - Main app clears pending attachments after processing
public enum SharedDataService {

    /// App Group identifier - must match entitlements in both targets
    public static let appGroupID = "group.com.hherb.locumtracker"

    private static let assignmentsCacheFilename = "cached_assignments.json"
    private static let pendingAttachmentsFilename = "pending_attachments.json"
    private static let pendingFilesDirectory = "PendingFiles"

    // MARK: - Container Access

    /// URL of the shared App Group container
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// URL of the pending files directory within the container
    private static var pendingFilesURL: URL? {
        guard let container = containerURL else { return nil }
        let url = container.appendingPathComponent(pendingFilesDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Assignments Cache

    /// Write cached assignments to App Group for Share Extension picker
    ///
    /// - Parameter assignments: Array of cached assignment data
    /// - Throws: SharedDataError if container unavailable or write fails
    public static func writeAssignmentsCache(_ assignments: [CachedAssignment]) throws {
        guard let container = containerURL else {
            throw SharedDataError.containerNotAvailable
        }
        let url = container.appendingPathComponent(assignmentsCacheFilename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(assignments)
        try data.write(to: url, options: .atomic)
    }

    /// Read cached assignments from App Group
    ///
    /// - Returns: Array of cached assignments, empty if unavailable
    public static func readAssignmentsCache() -> [CachedAssignment] {
        guard let container = containerURL else { return [] }
        let url = container.appendingPathComponent(assignmentsCacheFilename)
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CachedAssignment].self, from: data)) ?? []
    }

    // MARK: - Pending Attachments

    /// Write a pending attachment to App Group for main app processing
    ///
    /// - Parameters:
    ///   - attachment: Pending attachment metadata
    ///   - fileData: Actual file data to store
    /// - Throws: SharedDataError if container unavailable or write fails
    public static func writePendingAttachment(
        _ attachment: PendingAttachment,
        fileData: Data
    ) throws {
        guard let container = containerURL,
              let filesDir = pendingFilesURL else {
            throw SharedDataError.containerNotAvailable
        }

        // Write file data to pending files directory
        let fileURL = filesDir.appendingPathComponent(attachment.fileDataFilename)
        try fileData.write(to: fileURL, options: .atomic)

        // Append to pending attachments list
        var pending = readPendingAttachments()
        pending.append(attachment)

        let listURL = container.appendingPathComponent(pendingAttachmentsFilename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(pending)
        try data.write(to: listURL, options: .atomic)
    }

    /// Read all pending attachments from App Group
    ///
    /// - Returns: Array of pending attachments, empty if none
    public static func readPendingAttachments() -> [PendingAttachment] {
        guard let container = containerURL else { return [] }
        let url = container.appendingPathComponent(pendingAttachmentsFilename)
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([PendingAttachment].self, from: data)) ?? []
    }

    /// Read file data for a pending attachment
    ///
    /// - Parameter filename: The fileDataFilename from PendingAttachment
    /// - Returns: File data if found, nil otherwise
    public static func readPendingFileData(filename: String) -> Data? {
        guard let filesDir = pendingFilesURL else { return nil }
        let url = filesDir.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    /// Clear a processed pending attachment
    ///
    /// Removes both the file data and the pending attachment record.
    ///
    /// - Parameter attachment: The attachment to clear
    /// - Throws: SharedDataError if write fails
    public static func clearPendingAttachment(_ attachment: PendingAttachment) throws {
        guard let container = containerURL,
              let filesDir = pendingFilesURL else { return }

        // Remove file data
        let fileURL = filesDir.appendingPathComponent(attachment.fileDataFilename)
        try? FileManager.default.removeItem(at: fileURL)

        // Remove from pending list
        var pending = readPendingAttachments()
        pending.removeAll { $0.id == attachment.id }

        let listURL = container.appendingPathComponent(pendingAttachmentsFilename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(pending)
        try data.write(to: listURL, options: .atomic)
    }

    /// Clear all pending attachments
    ///
    /// Use with caution - removes all pending data without processing.
    public static func clearAllPendingAttachments() {
        guard let container = containerURL,
              let filesDir = pendingFilesURL else { return }

        // Clear files directory
        try? FileManager.default.removeItem(at: filesDir)
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)

        // Clear pending list
        let listURL = container.appendingPathComponent(pendingAttachmentsFilename)
        try? FileManager.default.removeItem(at: listURL)
    }

    /// Check if there are pending attachments to process
    ///
    /// - Returns: True if there are pending attachments
    public static func hasPendingAttachments() -> Bool {
        !readPendingAttachments().isEmpty
    }

    // MARK: - Errors

    public enum SharedDataError: Error, LocalizedError {
        case containerNotAvailable
        case fileWriteFailed
        case fileReadFailed

        public var errorDescription: String? {
            switch self {
            case .containerNotAvailable:
                return "App Group container not available. Ensure App Groups are configured in entitlements."
            case .fileWriteFailed:
                return "Failed to write file to shared container."
            case .fileReadFailed:
                return "Failed to read file from shared container."
            }
        }
    }
}
