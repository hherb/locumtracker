import Foundation
import SwiftData
import LocumTrackerCore

/// Repository for QuarterlyQuota model CRUD operations
public final class QuarterlyQuotaRepository: Repository {
    public typealias Model = QuarterlyQuota

    public let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Find By ID

    /// Finds a quarterly quota by its UUID
    /// - Parameter id: The quota ID
    /// - Returns: QuarterlyQuota if found
    public func findById(_ id: UUID) -> QuarterlyQuota? {
        let predicate = #Predicate<QuarterlyQuota> { $0.id == id }
        return fetch(predicate: predicate, sortDescriptors: [], fetchLimit: 1).first
    }

    // MARK: - Specialized Queries

    /// Fetches the quota for a specific quarter
    /// - Parameters:
    ///   - quarterStart: Start date of the quarter
    ///   - practitionerId: The practitioner's UUID
    /// - Returns: QuarterlyQuota if found
    public func fetchByQuarter(quarterStart: Date, practitionerId: UUID) -> QuarterlyQuota? {
        let calendar = Calendar.current
        let startOfQuarter = calendar.startOfDay(for: quarterStart)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfQuarter)!

        let predicate = #Predicate<QuarterlyQuota> {
            $0.practitionerId == practitionerId &&
            $0.quarterStartDate >= startOfQuarter &&
            $0.quarterStartDate < endOfDay
        }
        return fetch(predicate: predicate, sortDescriptors: [], fetchLimit: 1).first
    }

    /// Fetches the current quarter's quota for a practitioner
    /// - Parameter practitionerId: The practitioner's UUID
    /// - Returns: QuarterlyQuota for current quarter if found
    public func fetchCurrentQuarter(practitionerId: UUID) -> QuarterlyQuota? {
        let calendar = Calendar.current
        guard let quarterInterval = calendar.dateInterval(of: .quarter, for: Date()) else {
            return nil
        }
        return fetchByQuarter(quarterStart: quarterInterval.start, practitionerId: practitionerId)
    }

    /// Fetches all quotas for a practitioner
    /// - Parameter practitionerId: The practitioner's UUID
    /// - Returns: Array of quotas sorted by quarter (newest first)
    public func fetchByPractitioner(_ practitionerId: UUID) -> [QuarterlyQuota] {
        let predicate = #Predicate<QuarterlyQuota> { $0.practitionerId == practitionerId }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.quarterStartDate, order: .reverse)]
        )
    }

    /// Fetches quotas for a specific year
    /// - Parameters:
    ///   - year: The calendar year
    ///   - practitionerId: The practitioner's UUID
    /// - Returns: Array of quotas for that year
    public func fetchByYear(_ year: Int, practitionerId: UUID) -> [QuarterlyQuota] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1

        guard let yearStart = calendar.date(from: components),
              let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) else {
            return []
        }

        let predicate = #Predicate<QuarterlyQuota> {
            $0.practitionerId == practitionerId &&
            $0.quarterStartDate >= yearStart &&
            $0.quarterStartDate < yearEnd
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.quarterStartDate, order: .forward)]
        )
    }

    /// Fetches active quarters (quota met)
    /// - Parameter practitionerId: The practitioner's UUID
    /// - Returns: Array of quotas where quota was met
    public func fetchActiveQuarters(practitionerId: UUID) -> [QuarterlyQuota] {
        let predicate = #Predicate<QuarterlyQuota> {
            $0.practitionerId == practitionerId && $0.quotaMet == true
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.quarterStartDate, order: .reverse)]
        )
    }

    /// Fetches the most recent N quarters for a practitioner
    /// - Parameters:
    ///   - count: Number of quarters to fetch
    ///   - practitionerId: The practitioner's UUID
    /// - Returns: Array of most recent quotas
    public func fetchRecentQuarters(_ count: Int, practitionerId: UUID) -> [QuarterlyQuota] {
        let predicate = #Predicate<QuarterlyQuota> { $0.practitionerId == practitionerId }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.quarterStartDate, order: .reverse)],
            fetchLimit: count
        )
    }

    /// Counts active quarters within a reference period
    /// - Parameters:
    ///   - startDate: Start of reference period
    ///   - endDate: End of reference period
    ///   - practitionerId: The practitioner's UUID
    /// - Returns: Number of active quarters in the period
    public func countActiveQuarters(startDate: Date, endDate: Date, practitionerId: UUID) -> Int {
        let predicate = #Predicate<QuarterlyQuota> {
            $0.practitionerId == practitionerId &&
            $0.quotaMet == true &&
            $0.quarterStartDate >= startDate &&
            $0.quarterStartDate <= endDate
        }
        return count(predicate: predicate)
    }

    /// Gets or creates a quota for the current quarter
    /// - Parameter practitionerId: The practitioner's UUID
    /// - Returns: Existing or new QuarterlyQuota for current quarter
    public func getOrCreateCurrentQuarter(practitionerId: UUID) -> QuarterlyQuota {
        if let existing = fetchCurrentQuarter(practitionerId: practitionerId) {
            return existing
        }

        let newQuota = QuarterlyQuota.currentQuarter(for: practitionerId)
        insert(newQuota)
        return newQuota
    }
}
