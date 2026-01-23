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

/// Fluent query builder for DailyRecord model
public final class DailyRecordQueryBuilder: QueryBuilder {
    public typealias Model = DailyRecord

    // MARK: - Filter State

    private var dateRangeStart: Date?
    private var dateRangeEnd: Date?
    private var assignmentIds: [UUID]?
    private var minEarnings: Double?
    private var hasSubsidyEarnings: Bool?

    // MARK: - Sort State

    private var sortByDate: SortOrder = .reverse

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

    /// Filters by current month
    /// - Returns: Self for chaining
    @discardableResult
    public func currentMonth() -> Self {
        let calendar = Calendar.current
        if let interval = calendar.dateInterval(of: .month, for: Date()) {
            self.dateRangeStart = interval.start
            self.dateRangeEnd = interval.end
        }
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

    /// Filters by current year
    /// - Returns: Self for chaining
    @discardableResult
    public func currentYear() -> Self {
        let calendar = Calendar.current
        if let interval = calendar.dateInterval(of: .year, for: Date()) {
            self.dateRangeStart = interval.start
            self.dateRangeEnd = interval.end
        }
        return self
    }

    /// Filters by assignment IDs
    /// - Parameter ids: Array of assignment UUIDs
    /// - Returns: Self for chaining
    @discardableResult
    public func forAssignments(_ ids: [UUID]) -> Self {
        self.assignmentIds = ids
        return self
    }

    /// Filters by a single assignment
    /// - Parameter id: The assignment's UUID
    /// - Returns: Self for chaining
    @discardableResult
    public func forAssignment(_ id: UUID) -> Self {
        self.assignmentIds = [id]
        return self
    }

    /// Filters by minimum earnings
    /// - Parameter amount: Minimum earnings amount
    /// - Returns: Self for chaining
    @discardableResult
    public func minimumEarnings(_ amount: Double) -> Self {
        self.minEarnings = amount
        return self
    }

    /// Filters to records with subsidy earnings
    /// - Returns: Self for chaining
    @discardableResult
    public func withSubsidyEarnings() -> Self {
        self.hasSubsidyEarnings = true
        return self
    }

    /// Filters to records without subsidy earnings
    /// - Returns: Self for chaining
    @discardableResult
    public func withoutSubsidyEarnings() -> Self {
        self.hasSubsidyEarnings = false
        return self
    }

    /// Sorts by date
    /// - Parameter order: Sort order (default: reverse/newest first)
    /// - Returns: Self for chaining
    @discardableResult
    public func sortByDate(_ order: SortOrder = .reverse) -> Self {
        self.sortByDate = order
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

    public func buildPredicate() -> Predicate<DailyRecord>? {
        if let start = dateRangeStart, let end = dateRangeEnd {
            return #Predicate<DailyRecord> {
                $0.date >= start && $0.date <= end
            }
        }
        return nil
    }

    public func buildSortDescriptors() -> [SortDescriptor<DailyRecord>] {
        [SortDescriptor(\.date, order: sortByDate)]
    }

    public func execute(in context: ModelContext) -> [DailyRecord] {
        var descriptor = FetchDescriptor<DailyRecord>(
            predicate: buildPredicate(),
            sortBy: buildSortDescriptors()
        )

        if let fetchLimit = limitCount {
            descriptor.fetchLimit = fetchLimit
        }

        do {
            var results = try context.fetch(descriptor)

            // Post-fetch filtering
            if let ids = assignmentIds {
                let idSet = Set(ids)
                results = results.filter { idSet.contains($0.assignmentId) }
            }

            if let min = minEarnings {
                results = results.filter { $0.totalEarnings >= min }
            }

            if let hasSubsidy = hasSubsidyEarnings {
                if hasSubsidy {
                    results = results.filter { $0.subsidyEarnings != nil }
                } else {
                    results = results.filter { $0.subsidyEarnings == nil }
                }
            }

            return results
        } catch {
            return []
        }
    }
}
