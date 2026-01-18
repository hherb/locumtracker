import Foundation
import SwiftData
import LocumTrackerCore

/// Fluent query builder for Assignment model
public final class AssignmentQueryBuilder: QueryBuilder {
    public typealias Model = Assignment

    // MARK: - Filter State

    private var dateRangeStart: Date?
    private var dateRangeEnd: Date?
    private var statuses: [AssignmentStatus]?
    private var locationId: UUID?
    private var rateStructure: RateStructure?

    // MARK: - Sort State

    private var sortByStartDate: SortOrder = .reverse

    // MARK: - Limit

    private var limitCount: Int?

    // MARK: - Initialization

    public init() {}

    // MARK: - Fluent API

    /// Filters by date range (assignments overlapping the range)
    /// - Parameters:
    ///   - start: Start of range
    ///   - end: End of range
    /// - Returns: Self for chaining
    @discardableResult
    public func dateRange(from start: Date, to end: Date) -> Self {
        self.dateRangeStart = start
        self.dateRangeEnd = end
        return self
    }

    /// Filters by assignment statuses
    /// - Parameter statuses: Array of statuses to include
    /// - Returns: Self for chaining
    @discardableResult
    public func statuses(_ statuses: [AssignmentStatus]) -> Self {
        self.statuses = statuses
        return self
    }

    /// Filters by a single status
    /// - Parameter status: The status to filter by
    /// - Returns: Self for chaining
    @discardableResult
    public func status(_ status: AssignmentStatus) -> Self {
        self.statuses = [status]
        return self
    }

    /// Filters to active assignments only
    /// - Returns: Self for chaining
    @discardableResult
    public func activeOnly() -> Self {
        self.statuses = [.active]
        return self
    }

    /// Filters to planned assignments only
    /// - Returns: Self for chaining
    @discardableResult
    public func plannedOnly() -> Self {
        self.statuses = [.planned]
        return self
    }

    /// Filters to completed assignments only
    /// - Returns: Self for chaining
    @discardableResult
    public func completedOnly() -> Self {
        self.statuses = [.completed]
        return self
    }

    /// Filters to non-cancelled assignments
    /// - Returns: Self for chaining
    @discardableResult
    public func excludeCancelled() -> Self {
        self.statuses = [.planned, .active, .completed]
        return self
    }

    /// Filters by location
    /// - Parameter id: The location's UUID
    /// - Returns: Self for chaining
    @discardableResult
    public func forLocation(_ id: UUID) -> Self {
        self.locationId = id
        return self
    }

    /// Filters by rate structure
    /// - Parameter structure: The rate structure type
    /// - Returns: Self for chaining
    @discardableResult
    public func rateStructure(_ structure: RateStructure) -> Self {
        self.rateStructure = structure
        return self
    }

    /// Sorts by start date
    /// - Parameter order: Sort order (default: reverse/newest first)
    /// - Returns: Self for chaining
    @discardableResult
    public func sortByStartDate(_ order: SortOrder = .reverse) -> Self {
        self.sortByStartDate = order
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

    public func buildPredicate() -> Predicate<Assignment>? {
        // Build predicate for date range overlap
        if let start = dateRangeStart, let end = dateRangeEnd {
            return #Predicate<Assignment> {
                $0.startDate <= end && $0.endDate >= start
            }
        }
        return nil
    }

    public func buildSortDescriptors() -> [SortDescriptor<Assignment>] {
        [SortDescriptor(\.startDate, order: sortByStartDate)]
    }

    public func execute(in context: ModelContext) -> [Assignment] {
        var descriptor = FetchDescriptor<Assignment>(
            predicate: buildPredicate(),
            sortBy: buildSortDescriptors()
        )

        if let fetchLimit = limitCount {
            descriptor.fetchLimit = fetchLimit
        }

        do {
            var results = try context.fetch(descriptor)

            // Post-fetch filtering
            if let statusList = statuses {
                let statusSet = Set(statusList)
                results = results.filter { statusSet.contains($0.status) }
            }

            if let locId = locationId {
                results = results.filter { $0.locationId == locId }
            }

            if let rate = rateStructure {
                results = results.filter { $0.rateStructure == rate }
            }

            return results
        } catch {
            return []
        }
    }
}
