import Foundation
import SwiftData
import LocumTrackerCore

/// Repository for Receipt model CRUD operations
public final class ReceiptRepository: Repository {
    public typealias Model = Receipt

    public let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Find By ID

    /// Finds a receipt by its UUID
    /// - Parameter id: The receipt ID
    /// - Returns: Receipt if found
    public func findById(_ id: UUID) -> Receipt? {
        let predicate = #Predicate<Receipt> { $0.id == id }
        return fetch(predicate: predicate, sortDescriptors: [], fetchLimit: 1).first
    }

    // MARK: - Specialized Queries

    /// Fetches receipts by category
    /// - Parameter category: The expense category to filter by
    /// - Returns: Array of receipts in that category
    public func fetchByCategory(_ category: ExpenseCategory) -> [Receipt] {
        let predicate = #Predicate<Receipt> { $0.category == category }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Fetches receipts for a specific assignment
    /// - Parameter assignmentId: The assignment's UUID
    /// - Returns: Array of receipts for that assignment
    public func fetchByAssignment(_ assignmentId: UUID) -> [Receipt] {
        let predicate = #Predicate<Receipt> { $0.assignmentId == assignmentId }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Fetches receipts for a specific daily record
    /// - Parameter dailyRecordId: The daily record's UUID
    /// - Returns: Array of receipts for that daily record
    public func fetchByDailyRecord(_ dailyRecordId: UUID) -> [Receipt] {
        let predicate = #Predicate<Receipt> { $0.dailyRecordId == dailyRecordId }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Fetches receipts within a date range
    /// - Parameters:
    ///   - startDate: Start of range (inclusive)
    ///   - endDate: End of range (inclusive)
    /// - Returns: Array of receipts sorted by date (newest first)
    public func fetchByDateRange(startDate: Date, endDate: Date) -> [Receipt] {
        let predicate = #Predicate<Receipt> {
            $0.date >= startDate && $0.date <= endDate
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Fetches receipts with images
    /// - Returns: Array of receipts that have image data
    public func fetchWithImages() -> [Receipt] {
        let predicate = #Predicate<Receipt> { $0.imageData != nil }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Fetches receipts without images
    /// - Returns: Array of receipts that don't have image data
    public func fetchWithoutImages() -> [Receipt] {
        let predicate = #Predicate<Receipt> { $0.imageData == nil }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Fetches receipts above a minimum amount
    /// - Parameter minAmount: Minimum receipt amount
    /// - Returns: Array of receipts with amount >= threshold
    public func fetchWithMinimumAmount(_ minAmount: Double) -> [Receipt] {
        let predicate = #Predicate<Receipt> { $0.amount >= minAmount }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    /// Calculates total expenses for a date range
    /// - Parameters:
    ///   - startDate: Start of range
    ///   - endDate: End of range
    /// - Returns: Total expense amount
    public func totalExpenses(startDate: Date, endDate: Date) -> Double {
        let receipts = fetchByDateRange(startDate: startDate, endDate: endDate)
        return receipts.reduce(0) { $0 + $1.amount }
    }

    /// Calculates total expenses by category for a date range
    /// - Parameters:
    ///   - startDate: Start of range
    ///   - endDate: End of range
    /// - Returns: Dictionary of category to total amount
    public func totalsByCategory(startDate: Date, endDate: Date) -> [ExpenseCategory: Double] {
        let receipts = fetchByDateRange(startDate: startDate, endDate: endDate)
        var totals: [ExpenseCategory: Double] = [:]
        for receipt in receipts {
            totals[receipt.category, default: 0] += receipt.amount
        }
        return totals
    }
}
