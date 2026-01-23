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

/// Fluent query builder for Receipt model
public final class ReceiptQueryBuilder: QueryBuilder {
    public typealias Model = Receipt

    // MARK: - Filter State

    private var dateRangeStart: Date?
    private var dateRangeEnd: Date?
    private var categories: [ExpenseCategory]?
    private var assignmentId: UUID?
    private var dailyRecordId: UUID?
    private var hasImageOnly: Bool = false
    private var minAmount: Double?

    // MARK: - Sort State

    private var sortOrder: SortOrder = .reverse

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

    /// Filters by expense categories
    /// - Parameter cats: Array of expense categories
    /// - Returns: Self for chaining
    @discardableResult
    public func categories(_ cats: [ExpenseCategory]) -> Self {
        self.categories = cats
        return self
    }

    /// Filters by a single category
    /// - Parameter category: The expense category
    /// - Returns: Self for chaining
    @discardableResult
    public func category(_ category: ExpenseCategory) -> Self {
        self.categories = [category]
        return self
    }

    /// Filters by assignment
    /// - Parameter id: The assignment's UUID
    /// - Returns: Self for chaining
    @discardableResult
    public func forAssignment(_ id: UUID) -> Self {
        self.assignmentId = id
        return self
    }

    /// Filters by daily record
    /// - Parameter id: The daily record's UUID
    /// - Returns: Self for chaining
    @discardableResult
    public func forDailyRecord(_ id: UUID) -> Self {
        self.dailyRecordId = id
        return self
    }

    /// Filters to only receipts with images
    /// - Returns: Self for chaining
    @discardableResult
    public func withImagesOnly() -> Self {
        self.hasImageOnly = true
        return self
    }

    /// Filters by minimum amount
    /// - Parameter amount: Minimum receipt amount
    /// - Returns: Self for chaining
    @discardableResult
    public func minimumAmount(_ amount: Double) -> Self {
        self.minAmount = amount
        return self
    }

    /// Filters to tax-deductible categories only
    /// - Returns: Self for chaining
    @discardableResult
    public func taxDeductibleOnly() -> Self {
        self.categories = ExpenseCategory.allCases.filter { $0.isTaxDeductible }
        return self
    }

    /// Sorts by date
    /// - Parameter order: Sort order (default: reverse/newest first)
    /// - Returns: Self for chaining
    @discardableResult
    public func sortByDate(_ order: SortOrder = .reverse) -> Self {
        self.sortOrder = order
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

    public func buildPredicate() -> Predicate<Receipt>? {
        if let start = dateRangeStart, let end = dateRangeEnd {
            return #Predicate<Receipt> {
                $0.date >= start && $0.date <= end
            }
        }
        return nil
    }

    public func buildSortDescriptors() -> [SortDescriptor<Receipt>] {
        [SortDescriptor(\.date, order: sortOrder)]
    }

    public func execute(in context: ModelContext) -> [Receipt] {
        var descriptor = FetchDescriptor<Receipt>(
            predicate: buildPredicate(),
            sortBy: buildSortDescriptors()
        )

        if let fetchLimit = limitCount {
            descriptor.fetchLimit = fetchLimit
        }

        do {
            var results = try context.fetch(descriptor)

            // Post-fetch filtering
            if let cats = categories {
                let catSet = Set(cats)
                results = results.filter { catSet.contains($0.category) }
            }

            if let aId = assignmentId {
                results = results.filter { $0.assignmentId == aId }
            }

            if let drId = dailyRecordId {
                results = results.filter { $0.dailyRecordId == drId }
            }

            if hasImageOnly {
                results = results.filter { $0.hasImage }
            }

            if let min = minAmount {
                results = results.filter { $0.amount >= min }
            }

            return results
        } catch {
            return []
        }
    }
}
