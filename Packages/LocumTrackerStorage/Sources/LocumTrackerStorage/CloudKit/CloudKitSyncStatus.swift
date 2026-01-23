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
import SwiftUI

/// Sync state enumeration for CloudKit synchronization
public enum SyncState: String, Sendable {
    case idle = "Idle"
    case syncing = "Syncing"
    case synced = "Synced"
    case pending = "Pending Changes"
    case error = "Sync Error"

    /// SF Symbol name for this state
    public var systemImage: String {
        switch self {
        case .idle: return "cloud"
        case .syncing: return "arrow.triangle.2.circlepath.cloud"
        case .synced: return "checkmark.icloud"
        case .pending: return "arrow.clockwise.icloud"
        case .error: return "exclamationmark.icloud"
        }
    }

    /// Color for this state
    public var color: Color {
        switch self {
        case .idle: return .secondary
        case .syncing: return .blue
        case .synced: return .green
        case .pending: return .orange
        case .error: return .red
        }
    }
}

/// Observable class tracking CloudKit sync status
@Observable
public final class CloudKitSyncStatus {

    /// Current sync state
    public private(set) var state: SyncState = .idle

    /// Last successful sync timestamp
    public private(set) var lastSyncDate: Date?

    /// Error message if state is .error
    public private(set) var errorMessage: String?

    /// Number of pending changes
    public private(set) var pendingChangesCount: Int = 0

    /// Whether CloudKit is available
    public private(set) var isCloudKitAvailable: Bool = true

    // MARK: - Singleton

    /// Shared instance for app-wide access
    public static let shared = CloudKitSyncStatus()

    private init() {}

    // MARK: - State Updates (called by CloudKitSyncMonitor)

    /// Updates the current sync state
    /// - Parameter newState: The new state
    func updateState(_ newState: SyncState) {
        state = newState
        if newState == .synced {
            lastSyncDate = Date()
            errorMessage = nil
        }
    }

    /// Sets an error state with message
    /// - Parameter message: The error message
    func setError(_ message: String) {
        state = .error
        errorMessage = message
    }

    /// Updates the pending changes count
    /// - Parameter count: Number of pending changes
    func setPendingChanges(_ count: Int) {
        pendingChangesCount = count
        if count > 0 && state != .syncing && state != .error {
            state = .pending
        }
    }

    /// Updates CloudKit availability
    /// - Parameter available: Whether CloudKit is available
    func setCloudKitAvailability(_ available: Bool) {
        isCloudKitAvailable = available
    }

    // MARK: - Computed Properties

    /// Human-readable last sync description
    public var lastSyncDescription: String {
        guard let date = lastSyncDate else {
            return "Never synced"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    /// Whether sync is currently in progress
    public var isSyncing: Bool {
        state == .syncing
    }

    /// Status description combining state and details
    public var statusDescription: String {
        switch state {
        case .idle:
            return isCloudKitAvailable ? "Ready" : "iCloud unavailable"
        case .syncing:
            return "Syncing..."
        case .synced:
            return lastSyncDescription
        case .pending:
            return "\(pendingChangesCount) pending"
        case .error:
            return errorMessage ?? "Sync error"
        }
    }
}
