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
import CloudKit

/// Monitors CloudKit sync events and updates CloudKitSyncStatus
public final class CloudKitSyncMonitor {

    private let status: CloudKitSyncStatus
    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Initialization

    /// Creates a new sync monitor
    /// - Parameter status: The status object to update (defaults to shared)
    public init(status: CloudKitSyncStatus = .shared) {
        self.status = status
        setupObservers()
    }

    deinit {
        removeObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe CloudKit account status changes
        let accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAccountStatus()
        }
        notificationObservers.append(accountObserver)

        // Initial account check
        checkAccountStatus()
    }

    private func removeObservers() {
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        notificationObservers.removeAll()
    }

    // MARK: - Status Checks

    private func checkAccountStatus() {
        Task { @MainActor in
            do {
                let container = CKContainer(identifier: LocumTrackerStorage.cloudKitContainerID)
                let accountStatus = try await container.accountStatus()

                switch accountStatus {
                case .available:
                    status.setCloudKitAvailability(true)
                    if status.state == .error {
                        status.updateState(.idle)
                    }
                case .noAccount:
                    status.setCloudKitAvailability(false)
                    status.setError("No iCloud account")
                case .restricted:
                    status.setCloudKitAvailability(false)
                    status.setError("iCloud restricted")
                case .couldNotDetermine:
                    status.setCloudKitAvailability(false)
                    status.setError("Could not determine iCloud status")
                case .temporarilyUnavailable:
                    status.setCloudKitAvailability(false)
                    status.setError("iCloud temporarily unavailable")
                @unknown default:
                    status.setCloudKitAvailability(false)
                    status.setError("Unknown iCloud status")
                }
            } catch {
                status.setCloudKitAvailability(false)
                status.setError("Could not check iCloud: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Sync Events

    /// Called when a save operation starts
    public func willSave() {
        status.updateState(.syncing)
    }

    /// Called when a save operation completes successfully
    public func didSave() {
        // After save, assume sync will happen
        // SwiftData + CloudKit syncs automatically
        Task { @MainActor in
            // Give CloudKit a moment to sync
            try? await Task.sleep(for: .seconds(1))
            if status.state == .syncing {
                status.updateState(.synced)
            }
        }
    }

    /// Called when a save operation fails
    /// - Parameter error: The error that occurred
    public func didFailSave(_ error: Error) {
        status.setError(error.localizedDescription)
    }

    // MARK: - Manual Refresh

    /// Triggers a manual status refresh
    public func refreshStatus() {
        checkAccountStatus()
    }

    /// Manually marks sync as complete
    public func markSynced() {
        status.updateState(.synced)
    }

    /// Manually marks sync as in progress
    public func markSyncing() {
        status.updateState(.syncing)
    }
}
