import Foundation
import SwiftData
import LocumTrackerCore

/// Fluent query builder for Session model
public final class SessionQueryBuilder: QueryBuilder {
    public typealias Model = Session

    // MARK: - Filter State

    private var dateRangeStart: Date?
    private var dateRangeEnd: Date?
    private var dailyRecordIds: [UUID]?
    private var mmmClassifications: [Int]?
    private var sessionTypes: [SessionType]?
    private var minimumDuration: Double?
    private var subsidyEligibleOnly: Bool = false

    // MARK: - Sort State

    private var sortByStartTime: SortOrder?

    // MARK: - Limit

    private var limitCount: Int?

    // MARK: - Initialization

    public init() {}

    // MARK: - Fluent API

    /// Filters by date range
    /// - Parameters:
    ///   - start: Start of range (inclusive)
    ///   - end: End of range (inclusive)
    /// - Returns: Self for chaining
    @discardableResult
    public func dateRange(from start: Date, to end: Date) -> Self {
        self.dateRangeStart = start
        self.dateRangeEnd = end
        return self
    }

    /// Filters by current quarter
    /// - Returns: Self for chaining
    @discardableResult
    public func currentQuarter() -> Self {
        let calendar = Calendar.current
        if let interval = calendar.dateInterval(of: .quarter, for: Date()) {
            self.dateRangeStart = interval.start
            self.dateRangeEnd = interval.end
        }
        return self
    }

    /// Filters by a specific quarter
    /// - Parameter quarterStart: First day of the quarter
    /// - Returns: Self for chaining
    @discardableResult
    public func quarter(starting quarterStart: Date) -> Self {
        let calendar = Calendar.current
        if let interval = calendar.dateInterval(of: .quarter, for: quarterStart) {
            self.dateRangeStart = interval.start
            self.dateRangeEnd = interval.end
        }
        return self
    }

    /// Filters by specific daily record IDs
    /// - Parameter ids: Array of daily record UUIDs
    /// - Returns: Self for chaining
    @discardableResult
    public func forDailyRecords(_ ids: [UUID]) -> Self {
        self.dailyRecordIds = ids
        return self
    }

    /// Filters by MMM classifications
    /// - Parameter mmms: Array of MMM levels (1-7)
    /// - Returns: Self for chaining
    @discardableResult
    public func mmmClassifications(_ mmms: [Int]) -> Self {
        self.mmmClassifications = mmms
        return self
    }

    /// Filters to subsidy-eligible locations only (MMM 3-7)
    /// - Returns: Self for chaining
    @discardableResult
    public func subsidyEligible() -> Self {
        self.subsidyEligibleOnly = true
        return self
    }

    /// Filters by session types
    /// - Parameter types: Array of session types
    /// - Returns: Self for chaining
    @discardableResult
    public func sessionTypes(_ types: [SessionType]) -> Self {
        self.sessionTypes = types
        return self
    }

    /// Filters by minimum duration (for FPS validation)
    /// - Parameter hours: Minimum session duration in hours
    /// - Returns: Self for chaining
    @discardableResult
    public func minimumDuration(hours: Double) -> Self {
        self.minimumDuration = hours
        return self
    }

    /// Configures for FPS-valid sessions (3+ hours, MMM 3-7)
    /// - Returns: Self for chaining
    @discardableResult
    public func fpsValid() -> Self {
        self.minimumDuration = RuralSubsidyService.minimumSessionHours
        self.subsidyEligibleOnly = true
        return self
    }

    /// Sorts by start time
    /// - Parameter order: Sort order (default: reverse/newest first)
    /// - Returns: Self for chaining
    @discardableResult
    public func sortByStartTime(_ order: SortOrder = .reverse) -> Self {
        self.sortByStartTime = order
        return self
    }

    /// Limits results
    /// - Parameter count: Maximum number of results
    /// - Returns: Self for chaining
    @discardableResult
    public func limit(_ count: Int) -> Self {
        self.limitCount = count
        return self
    }

    // MARK: - QueryBuilder Protocol

    public func buildPredicate() -> Predicate<Session>? {
        // Build the most specific predicate we can at compile time
        // Note: SwiftData predicates require compile-time literals, so we cannot use
        // RuralSubsidyService constants here. MMM 3-7 are the subsidy-eligible classifications.
        if let start = dateRangeStart, let end = dateRangeEnd {
            if subsidyEligibleOnly {
                return #Predicate<Session> {
                    $0.startTime >= start &&
                    $0.startTime <= end &&
                    $0.mmmClassification >= 3 &&
                    $0.mmmClassification <= 7
                }
            } else {
                return #Predicate<Session> {
                    $0.startTime >= start && $0.startTime <= end
                }
            }
        }

        if subsidyEligibleOnly {
            return #Predicate<Session> {
                $0.mmmClassification >= 3 && $0.mmmClassification <= 7
            }
        }

        return nil
    }

    public func buildSortDescriptors() -> [SortDescriptor<Session>] {
        var descriptors: [SortDescriptor<Session>] = []

        if let order = sortByStartTime {
            descriptors.append(SortDescriptor(\.startTime, order: order))
        }

        return descriptors
    }

    public func execute(in context: ModelContext) -> [Session] {
        var descriptor = FetchDescriptor<Session>(
            predicate: buildPredicate(),
            sortBy: buildSortDescriptors()
        )

        if let fetchLimit = limitCount {
            descriptor.fetchLimit = fetchLimit
        }

        do {
            var results = try context.fetch(descriptor)

            // Post-fetch filtering for conditions not expressible in predicates
            if let minDuration = minimumDuration {
                results = results.filter { $0.durationHours >= minDuration }
            }

            if let ids = dailyRecordIds {
                let idSet = Set(ids)
                results = results.filter { idSet.contains($0.dailyRecordId) }
            }

            if let types = sessionTypes {
                let typeSet = Set(types)
                results = results.filter { typeSet.contains($0.sessionType) }
            }

            if let mmms = mmmClassifications {
                let mmmSet = Set(mmms)
                results = results.filter { mmmSet.contains($0.mmmClassification) }
            }

            return results
        } catch {
            return []
        }
    }
}
