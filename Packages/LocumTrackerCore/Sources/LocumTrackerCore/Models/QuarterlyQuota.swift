import Foundation

/// Tracks quarterly rural subsidy compliance
/// Monitors MMM3-7 hours to ensure 40-hour quarterly quota is met
@Model
public final class QuarterlyQuota {
    /// Unique identifier for the quota record
    public var id: UUID
    
    /// ID of the practitioner this quota belongs to
    public var practitionerId: UUID
    
    /// First day of the quarter being tracked
    public var quarterDate: Date
    
    /// Hours worked in MMM3 locations
    public var mmm3Hours: Double = 0
    
    /// Hours worked in MMM4 locations
    public var mmm4Hours: Double = 0
    
    /// Hours worked in MMM5 locations
    public var mmm5Hours: Double = 0
    
    /// Hours worked in MMM6 locations
    public var mmm6Hours: Double = 0
    
    /// Hours worked in MMM7 locations
    public var mmm7Hours: Double = 0
    
    /// Total hours across all MMM3-7 locations
    public var totalHours: Double = 0
    
    /// Target hours for full quarterly subsidy
    public var targetHours: Double = 40
    
    /// Whether the quarterly quota has been met
    public var quotaMet: Bool = false
    
    /// Date when this quota record was last updated
    public var lastUpdated: Date
    
    /// Initialize a new quarterly quota record
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - practitionerId: ID of the practitioner
    ///   - quarterDate: First day of the quarter
    ///   - targetHours: Hours needed for full subsidy (default: 40)
    public init(
        id: UUID,
        practitionerId: UUID,
        quarterDate: Date,
        targetHours: Double = 40
    ) {
        self.id = id
        self.practitionerId = practitionerId
        self.quarterDate = quarterDate
        self.targetHours = targetHours
        self.lastUpdated = Date()
    }
    
    /// Returns the percentage progress toward quota
    public var progressPercentage: Double {
        guard targetHours > 0 else { return 0 }
        return (totalHours / targetHours) * 100
    }
    
    /// Returns the remaining hours needed to meet quota
    public var remainingHours: Double {
        return max(0, targetHours - totalHours)
    }
    
    /// Returns the quarter as a formatted string (e.g., "2024 Q3")
    public var quarterString: String {
        let calendar = Calendar.current
        let quarter = calendar.component(.quarter, from: quarterDate)
        let year = calendar.component(.year, from: quarterDate)
        return String(format: "%d Q%d", year, quarter)
    }
    
    /// Returns the end date of this quarter
    public var quarterEndDate: Date {
        let calendar = Calendar.current
        let quarter = calendar.component(.quarter, from: quarterDate)
        let year = calendar.component(.year, from: quarterDate)
        
        guard let startOfQuarter = calendar.date(from: DateComponents(year: year, month: (quarter - 1) * 3 + 1, day: 1)),
              let endOfQuarter = calendar.dateInterval(from: startOfQuarter, interval: DateComponents(month: 3))?.end else {
            return quarterDate
        }
        
        return endOfQuarter
    }
    
    /// Returns the number of days remaining in the quarter
    public var daysRemaining: Int {
        let calendar = Calendar.current
        let now = Date()
        let end = quarterEndDate
        
        let components = calendar.dateComponents([.day], from: now, to: end)
        return max(0, components.day ?? 0)
    }
    
    /// Updates quota with new session data
    /// - Parameters:
    ///   - mmmClassification: MMM classification of the session (3-7)
    ///   - hours: Hours worked in the session
    public func addSessionHours(mmmClassification: Int, hours: Double) {
        switch mmmClassification {
        case 3: mmm3Hours += hours
        case 4: mmm4Hours += hours
        case 5: mmm5Hours += hours
        case 6: mmm6Hours += hours
        case 7: mmm7Hours += hours
        default: break // MMM1-2 don't count toward quota
        }
        
        recalculateTotals()
    }
    
    /// Removes session hours from quota (for editing/deleting sessions)
    /// - Parameters:
    ///   - mmmClassification: MMM classification of the session (3-7)
    ///   - hours: Hours to remove
    public func removeSessionHours(mmmClassification: Int, hours: Double) {
        switch mmmClassification {
        case 3: mmm3Hours = max(0, mmm3Hours - hours)
        case 4: mmm4Hours = max(0, mmm4Hours - hours)
        case 5: mmm5Hours = max(0, mmm5Hours - hours)
        case 6: mmm6Hours = max(0, mmm6Hours - hours)
        case 7: mmm7Hours = max(0, mmm7Hours - hours)
        default: break // MMM1-2 don't count toward quota
        }
        
        recalculateTotals()
    }
    
    /// Returns progress status description
    public var progressStatus: String {
        if quotaMet {
            return "✅ Quota Met"
        } else if progressPercentage >= 75 {
            return "⚠️ Almost There"
        } else if progressPercentage >= 50 {
            return "📊 On Track"
        } else if progressPercentage >= 25 {
            return "🏃 Getting Started"
        } else {
            return "🚨 Action Needed"
        }
    }
    
    /// Determines if user is at risk of not meeting quota
    public var isAtRisk: Bool {
        return progressPercentage < 75 && daysRemaining < 30
    }
    
    /// Returns warning level for UI display
    public var warningLevel: WarningLevel {
        if isAtRisk {
            return .high
        } else if !quotaMet && daysRemaining < 14 {
            return .medium
        } else if quotaMet {
            return .success
        } else {
            return .low
        }
    }
    
    /// Recalculates total hours and quota status
    private func recalculateTotals() {
        totalHours = mmm3Hours + mmm4Hours + mmm5Hours + mmm6Hours + mmm7Hours
        quotaMet = totalHours >= targetHours
        lastUpdated = Date()
    }
}

/// Warning levels for quota progress
public enum WarningLevel: String, CaseIterable {
    case success = "success"
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    /// Color associated with warning level
    public var color: String {
        switch self {
        case .success: return "green"
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
    
    /// Icon for warning level
    public var icon: String {
        switch self {
        case .success: return "✅"
        case .low: return "💚"
        case .medium: return "⚠️"
        case .high: return "🚨"
        }
    }
}