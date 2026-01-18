import Foundation

/// Main module export for LocumTrackerCore
/// Provides access to all core services and utilities

@_exported import struct LocumTrackerCore {
    
    /// Module version
    public static let version = "1.0.0"
    
    /// Module build date
    public static let buildDate = "2024-01-18"
    
    /// Core services available in this module
    public struct Services {
        public static let ruralSubsidy = RuralSubsidyService.self
        public static let earnings = EarningsService.self
        public static let tax = TaxService.self
        public static let validation = ValidationService.self
    }
    
    /// Data models available in this module
    public struct Models {
        public typealias Location = LocumTrackerCore.Location
        public typealias Assignment = LocumTrackerCore.Assignment
        public typealias Session = LocumTrackerCore.Session
        public typealias DailyRecord = LocumTrackerCore.DailyRecord
        public typealias Receipt = LocumTrackerCore.Receipt
        public typealias LocumProfile = LocumTrackerCore.LocumProfile
        public typealias QuarterlyQuota = LocumTrackerCore.QuarterlyQuota
    }
    
    /// Utilities available in this module
    public struct Utilities {
        public static let dateFormatter = DateExtensions.self
    }
}