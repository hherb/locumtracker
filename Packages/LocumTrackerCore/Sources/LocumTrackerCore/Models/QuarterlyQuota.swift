import Foundation
import SwiftData

/// Warning levels for quota progress
public enum WarningLevel: String, CaseIterable, Codable {
    case success = "success"
    case low = "low"
    case medium = "medium"
    case high = "high"

    public var color: String {
        switch self {
        case .success: return "green"
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

/// Tracks quarterly rural subsidy compliance
/// Monitors MMM3-7 hours to ensure 40-hour quarterly quota is met
@Model
public final class QuarterlyQuota {
    public var id: UUID = UUID()
    public var practitionerId: UUID = UUID()
    public var quarterDate: Date = Date()
    public var mmm3Hours: Double = 0
    public var mmm4Hours: Double = 0
    public var mmm5Hours: Double = 0
    public var mmm6Hours: Double = 0
    public var mmm7Hours: Double = 0
    public var totalHours: Double = 0
    public var targetHours: Double = 40
    public var quotaMet: Bool = false
    public var lastUpdated: Date = Date()

    public init(
        id: UUID = UUID(),
        practitionerId: UUID,
        quarterDate: Date,
        targetHours: Double = 40
    ) {
        self.id = id
        self.practitionerId = practitionerId
        self.quarterDate = quarterDate
        self.targetHours = targetHours
        self.mmm3Hours = 0
        self.mmm4Hours = 0
        self.mmm5Hours = 0
        self.mmm6Hours = 0
        self.mmm7Hours = 0
        self.totalHours = 0
        self.quotaMet = false
        self.lastUpdated = Date()
    }

    /// Progress percentage toward quota
    public var progressPercentage: Double {
        guard targetHours > 0 else { return 0 }
        return (totalHours / targetHours) * 100
    }

    /// Remaining hours needed to meet quota
    public var remainingHours: Double {
        max(0, targetHours - totalHours)
    }

    /// Quarter as a formatted string (e.g., "2024 Q3")
    public var quarterString: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: quarterDate)
        let quarter = (month - 1) / 3 + 1
        let year = calendar.component(.year, from: quarterDate)
        return "\(year) Q\(quarter)"
    }

    /// Number of days remaining in the quarter
    public var daysRemaining: Int {
        let calendar = Calendar.current
        guard let quarterEnd = calendar.dateInterval(of: .quarter, for: quarterDate)?.end else {
            return 0
        }
        let components = calendar.dateComponents([.day], from: Date(), to: quarterEnd)
        return max(0, components.day ?? 0)
    }

    /// Whether user is at risk of not meeting quota
    public var isAtRisk: Bool {
        !quotaMet && progressPercentage < 75 && daysRemaining < 30
    }

    /// Warning level for UI display
    public var warningLevel: WarningLevel {
        if quotaMet {
            return .success
        } else if isAtRisk {
            return .high
        } else if daysRemaining < 14 {
            return .medium
        } else {
            return .low
        }
    }

    /// Updates quota with new session data
    public func addSessionHours(mmmClassification: Int, hours: Double) {
        switch mmmClassification {
        case 3: mmm3Hours += hours
        case 4: mmm4Hours += hours
        case 5: mmm5Hours += hours
        case 6: mmm6Hours += hours
        case 7: mmm7Hours += hours
        default: break
        }
        recalculateTotals()
    }

    /// Removes session hours from quota
    public func removeSessionHours(mmmClassification: Int, hours: Double) {
        switch mmmClassification {
        case 3: mmm3Hours = max(0, mmm3Hours - hours)
        case 4: mmm4Hours = max(0, mmm4Hours - hours)
        case 5: mmm5Hours = max(0, mmm5Hours - hours)
        case 6: mmm6Hours = max(0, mmm6Hours - hours)
        case 7: mmm7Hours = max(0, mmm7Hours - hours)
        default: break
        }
        recalculateTotals()
    }

    private func recalculateTotals() {
        totalHours = mmm3Hours + mmm4Hours + mmm5Hours + mmm6Hours + mmm7Hours
        quotaMet = totalHours >= targetHours
        lastUpdated = Date()
    }
}
