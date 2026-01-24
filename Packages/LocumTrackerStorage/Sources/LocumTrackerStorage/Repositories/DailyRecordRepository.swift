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

/// Repository for DailyRecord model CRUD operations
public final class DailyRecordRepository: Repository {
    public typealias Model = DailyRecord

    public let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Find By ID

    /// Finds a daily record by its UUID
    /// - Parameter id: The daily record ID
    /// - Returns: DailyRecord if found
    public func findById(_ id: UUID) -> DailyRecord? {
        let predicate = #Predicate<DailyRecord> { $0.id == id }
        return fetch(predicate: predicate, sortDescriptors: [], fetchLimit: 1).first
    }

    // MARK: - Specialized Queries

    /// Fetches daily records for a specific assignment
    /// - Parameter assignmentId: The assignment's UUID
    /// - Returns: Array of daily records sorted by date (newest first)
    public func fetchByAssignment(_ assignmentId: UUID) -> [DailyRecord] {
        let predicate = #Predicate<DailyRecord> { $0.assignmentId == assignmentId }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Fetches daily records within a date range
    /// - Parameters:
    ///   - startDate: Start of range (inclusive)
    ///   - endDate: End of range (inclusive)
    /// - Returns: Array of daily records sorted by date (newest first)
    public func fetchByDateRange(startDate: Date, endDate: Date) -> [DailyRecord] {
        let predicate = #Predicate<DailyRecord> {
            $0.date >= startDate && $0.date <= endDate
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Fetches a daily record for a specific date and assignment
    /// - Parameters:
    ///   - date: The date to find
    ///   - assignmentId: The assignment's UUID
    /// - Returns: DailyRecord if found
    public func fetchByDateAndAssignment(date: Date, assignmentId: UUID) -> DailyRecord? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<DailyRecord> {
            $0.assignmentId == assignmentId &&
            $0.date >= startOfDay &&
            $0.date < endOfDay
        }
        return fetch(predicate: predicate, sortDescriptors: [], fetchLimit: 1).first
    }

    /// Fetches daily records with earnings above a threshold
    /// - Parameter minEarnings: Minimum earnings amount
    /// - Returns: Array of daily records with earnings >= threshold
    public func fetchWithMinimumEarnings(_ minEarnings: Double) -> [DailyRecord] {
        let predicate = #Predicate<DailyRecord> { $0.totalEarnings >= minEarnings }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Fetches daily records that have subsidy earnings
    /// - Returns: Array of daily records with subsidy earnings
    public func fetchWithSubsidyEarnings() -> [DailyRecord] {
        let predicate = #Predicate<DailyRecord> { $0.subsidyEarnings != nil }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Calculates total earnings for a date range
    /// - Parameters:
    ///   - startDate: Start of range
    ///   - endDate: End of range
    /// - Returns: Total earnings amount
    public func totalEarnings(startDate: Date, endDate: Date) -> Double {
        let records = fetchByDateRange(startDate: startDate, endDate: endDate)
        return records.reduce(0) { $0 + $1.totalEarnings }
    }
}
