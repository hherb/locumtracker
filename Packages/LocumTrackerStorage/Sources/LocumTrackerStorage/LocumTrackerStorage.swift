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

// MARK: - Module Configuration

/// LocumTrackerStorage module
/// Provides SwiftData persistence and CloudKit integration
public enum LocumTrackerStorage {
    /// Module version
    public static let version = "1.0.0"

    /// CloudKit container identifier
    public static let cloudKitContainerID = "iCloud.com.hherb.locumtracker"
}

/// Schema configuration for SwiftData
public enum LocumTrackerSchema {
    /// Current schema version
    public static let schemaVersion = 1

    /// All model types for the schema
    public static var models: [any PersistentModel.Type] {
        [
            Location.self,
            Assignment.self,
            Session.self,
            DailyRecord.self,
            Receipt.self,
            LocumProfile.self,
            QuarterlyQuota.self,
            Attachment.self
        ]
    }
}

// MARK: - Public API Summary
//
// This module provides:
//
// ## Protocols
// - Repository: Generic repository protocol for CRUD operations
// - QueryBuilder: Protocol for building type-safe queries
//
// ## Repositories
// - SessionRepository: CRUD operations for Session model
// - AssignmentRepository: CRUD operations for Assignment model
// - DailyRecordRepository: CRUD operations for DailyRecord model
// - LocationRepository: CRUD operations for Location model
// - ReceiptRepository: CRUD operations for Receipt model
// - LocumProfileRepository: CRUD operations for LocumProfile model
// - QuarterlyQuotaRepository: CRUD operations for QuarterlyQuota model
//
// ## Query Builders
// - SessionQueryBuilder: Fluent query builder for sessions
// - ReceiptQueryBuilder: Fluent query builder for receipts
// - AssignmentQueryBuilder: Fluent query builder for assignments
// - DailyRecordQueryBuilder: Fluent query builder for daily records
//
// ## CloudKit
// - CloudKitSyncStatus: Observable sync status tracker
// - CloudKitSyncMonitor: Monitors CloudKit sync events
// - CloudKitSyncStatusView: SwiftUI component for sync status
// - CloudKitSyncStatusDetailView: Detailed SwiftUI sync status view
//
// ## Aggregates
// - FPSQuarterlyDataProvider: Cross-model queries for WIP FPS calculations
// - FPSSessionData: Session with related entities
// - QuotaSummary: Quarterly quota calculation results
