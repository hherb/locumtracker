import Foundation
import SwiftData
import LocumTrackerCore

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
            QuarterlyQuota.self
        ]
    }
}
