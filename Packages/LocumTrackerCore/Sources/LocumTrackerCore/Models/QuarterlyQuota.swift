import Foundation
import SwiftData

/// Warning levels for quota progress
public enum QuotaWarningLevel: String, CaseIterable, Codable {
    case success = "success"
    case onTrack = "on_track"
    case atRisk = "at_risk"
    case critical = "critical"

    public var description: String {
        switch self {
        case .success: return "Quota Met"
        case .onTrack: return "On Track"
        case .atRisk: return "At Risk"
        case .critical: return "Critical"
        }
    }
}

/// Tracks quarterly rural subsidy (WIP FPS) compliance
/// Monitors sessions at MMM3-7 locations to ensure 21-session quarterly quota is met
@Model
public final class QuarterlyQuota {
    // MARK: - Constants

    /// Minimum sessions required for an active quarter
    public static let minimumSessions: Int = 21

    /// Maximum sessions counted per quarter (excess doesn't carry over)
    public static let maximumSessions: Int = 104

    /// Minimum session duration in hours
    public static let minimumSessionDurationHours: Double = 3.0

    /// Maximum sessions countable per day
    public static let maximumSessionsPerDay: Int = 2

    // MARK: - Properties

    public var id: UUID = UUID()
    public var practitionerId: UUID = UUID()

    /// Start date of the quarter (first day of quarter)
    public var quarterStartDate: Date = Date()

    /// Session counts by MMM classification
    public var mmm3Sessions: Int = 0
    public var mmm4Sessions: Int = 0
    public var mmm5Sessions: Int = 0
    public var mmm6Sessions: Int = 0
    public var mmm7Sessions: Int = 0

    /// Total counted sessions (capped at 104)
    public var totalSessions: Int = 0

    /// Whether the minimum 21 sessions has been met
    public var quotaMet: Bool = false

    public var lastUpdated: Date = Date()

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        practitionerId: UUID,
        quarterStartDate: Date
    ) {
        self.id = id
        self.practitionerId = practitionerId
        self.quarterStartDate = quarterStartDate
        self.mmm3Sessions = 0
        self.mmm4Sessions = 0
        self.mmm5Sessions = 0
        self.mmm6Sessions = 0
        self.mmm7Sessions = 0
        self.totalSessions = 0
        self.quotaMet = false
        self.lastUpdated = Date()
    }

    // MARK: - Computed Properties

    /// Raw total sessions before capping
    public var rawTotalSessions: Int {
        mmm3Sessions + mmm4Sessions + mmm5Sessions + mmm6Sessions + mmm7Sessions
    }

    /// Progress percentage toward minimum quota (21 sessions)
    public var progressPercentage: Double {
        Double(totalSessions) / Double(Self.minimumSessions) * 100
    }

    /// Remaining sessions needed to meet minimum quota
    public var remainingSessions: Int {
        max(0, Self.minimumSessions - totalSessions)
    }

    /// Sessions over the countable maximum (these don't carry forward)
    public var excessSessions: Int {
        max(0, rawTotalSessions - Self.maximumSessions)
    }

    /// Quarter as a formatted string (e.g., "2024 Q3")
    public var quarterString: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: quarterStartDate)
        let quarter = (month - 1) / 3 + 1
        let year = calendar.component(.year, from: quarterStartDate)
        return "\(year) Q\(quarter)"
    }

    /// End date of the quarter
    public var quarterEndDate: Date {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .quarter, for: quarterStartDate) else {
            return quarterStartDate
        }
        return interval.end.addingTimeInterval(-1) // Last moment of quarter
    }

    /// Number of days remaining in the quarter
    public var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: quarterEndDate)
        return max(0, (components.day ?? 0) + 1)
    }

    /// Number of days elapsed in the quarter
    public var daysElapsed: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: quarterStartDate, to: Date())
        return max(0, components.day ?? 0)
    }

    /// Total days in the quarter
    public var totalDaysInQuarter: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: quarterStartDate, to: quarterEndDate)
        return (components.day ?? 0) + 1
    }

    /// Expected sessions based on time elapsed (for pacing)
    public var expectedSessionsToDate: Double {
        let progress = Double(daysElapsed) / Double(totalDaysInQuarter)
        return progress * Double(Self.minimumSessions)
    }

    /// Whether the user is behind the expected pace
    public var isBehindPace: Bool {
        Double(totalSessions) < expectedSessionsToDate
    }

    /// The predominant MMM classification (where most sessions were worked)
    public var predominantMMM: Int {
        let counts = [
            (3, mmm3Sessions),
            (4, mmm4Sessions),
            (5, mmm5Sessions),
            (6, mmm6Sessions),
            (7, mmm7Sessions)
        ]
        let maxCount = counts.max { $0.1 < $1.1 }
        return maxCount?.0 ?? 3
    }

    /// Warning level for UI display
    public var warningLevel: QuotaWarningLevel {
        if quotaMet {
            return .success
        }

        let percentComplete = progressPercentage

        // If less than 2 weeks left and under 75% complete
        if daysRemaining < 14 && percentComplete < 75 {
            return .critical
        }

        // If behind pace significantly
        if isBehindPace && percentComplete < 50 {
            return .atRisk
        }

        return .onTrack
    }

    // MARK: - Methods

    /// Adds a session to the quota
    /// - Parameter mmmClassification: The MMM classification of the session location
    public func addSession(mmmClassification: Int) {
        switch mmmClassification {
        case 3: mmm3Sessions += 1
        case 4: mmm4Sessions += 1
        case 5: mmm5Sessions += 1
        case 6: mmm6Sessions += 1
        case 7: mmm7Sessions += 1
        default: return // Not eligible
        }
        recalculateTotals()
    }

    /// Removes a session from the quota
    /// - Parameter mmmClassification: The MMM classification of the session location
    public func removeSession(mmmClassification: Int) {
        switch mmmClassification {
        case 3: mmm3Sessions = max(0, mmm3Sessions - 1)
        case 4: mmm4Sessions = max(0, mmm4Sessions - 1)
        case 5: mmm5Sessions = max(0, mmm5Sessions - 1)
        case 6: mmm6Sessions = max(0, mmm6Sessions - 1)
        case 7: mmm7Sessions = max(0, mmm7Sessions - 1)
        default: return
        }
        recalculateTotals()
    }

    /// Recalculates totals after session changes
    private func recalculateTotals() {
        totalSessions = min(rawTotalSessions, Self.maximumSessions)
        quotaMet = totalSessions >= Self.minimumSessions
        lastUpdated = Date()
    }

    /// Returns the session count for a specific MMM classification
    /// - Parameter mmm: The MMM classification (3-7)
    /// - Returns: Number of sessions at that classification
    public func sessions(for mmm: Int) -> Int {
        switch mmm {
        case 3: return mmm3Sessions
        case 4: return mmm4Sessions
        case 5: return mmm5Sessions
        case 6: return mmm6Sessions
        case 7: return mmm7Sessions
        default: return 0
        }
    }
}

// MARK: - Quarter Utilities

public extension QuarterlyQuota {
    /// Creates a QuarterlyQuota for the current quarter
    /// - Parameter practitionerId: The practitioner's ID
    /// - Returns: A new QuarterlyQuota starting at the beginning of the current quarter
    static func currentQuarter(for practitionerId: UUID) -> QuarterlyQuota {
        let calendar = Calendar.current
        let now = Date()
        guard let quarterInterval = calendar.dateInterval(of: .quarter, for: now) else {
            return QuarterlyQuota(practitionerId: practitionerId, quarterStartDate: now)
        }
        return QuarterlyQuota(practitionerId: practitionerId, quarterStartDate: quarterInterval.start)
    }

    /// Returns the quarter identifier (e.g., "2024-Q1")
    var quarterIdentifier: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: quarterStartDate)
        let month = calendar.component(.month, from: quarterStartDate)
        let quarter = (month - 1) / 3 + 1
        return "\(year)-Q\(quarter)"
    }
}
