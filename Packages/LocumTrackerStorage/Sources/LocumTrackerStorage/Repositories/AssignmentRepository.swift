import Foundation
import SwiftData
import LocumTrackerCore

/// Repository for Assignment model CRUD operations
public final class AssignmentRepository: Repository {
    public typealias Model = Assignment

    public let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Find By ID

    /// Finds an assignment by its UUID
    /// - Parameter id: The assignment ID
    /// - Returns: Assignment if found
    public func findById(_ id: UUID) -> Assignment? {
        let predicate = #Predicate<Assignment> { $0.id == id }
        return fetch(predicate: predicate, sortDescriptors: [], fetchLimit: 1).first
    }

    // MARK: - Specialized Queries

    /// Fetches assignments by status
    /// - Parameter status: The assignment status to filter by
    /// - Returns: Array of assignments with that status
    public func fetchByStatus(_ status: AssignmentStatus) -> [Assignment] {
        let predicate = #Predicate<Assignment> { $0.status == status }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }

    /// Fetches assignments for a specific location
    /// - Parameter locationId: The location's UUID
    /// - Returns: Array of assignments at that location
    public func fetchByLocation(_ locationId: UUID) -> [Assignment] {
        let predicate = #Predicate<Assignment> { $0.locationId == locationId }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }

    /// Fetches assignments overlapping a date range
    /// - Parameters:
    ///   - startDate: Start of range
    ///   - endDate: End of range
    /// - Returns: Array of overlapping assignments
    public func fetchByDateRange(startDate: Date, endDate: Date) -> [Assignment] {
        let predicate = #Predicate<Assignment> {
            $0.startDate <= endDate && $0.endDate >= startDate
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }

    /// Fetches active assignments (status = .active)
    /// - Returns: Array of active assignments
    public func fetchActive() -> [Assignment] {
        fetchByStatus(.active)
    }

    /// Fetches planned assignments (status = .planned)
    /// - Returns: Array of planned assignments
    public func fetchPlanned() -> [Assignment] {
        fetchByStatus(.planned)
    }

    /// Fetches current assignments (active and within date range)
    /// - Parameter referenceDate: Date to check against (defaults to now)
    /// - Returns: Array of current assignments
    public func fetchCurrent(referenceDate: Date = Date()) -> [Assignment] {
        // SwiftData predicates have limitations with enum comparisons in compound predicates
        // So we fetch by date range and filter by status in memory
        let predicate = #Predicate<Assignment> {
            $0.startDate <= referenceDate &&
            $0.endDate >= referenceDate
        }
        let results = fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return results.filter { $0.status == .active }
    }

    /// Fetches completed assignments
    /// - Returns: Array of completed assignments
    public func fetchCompleted() -> [Assignment] {
        fetchByStatus(.completed)
    }

    /// Fetches assignments by rate structure
    /// - Parameter rateStructure: The rate structure type
    /// - Returns: Array of assignments with that rate structure
    public func fetchByRateStructure(_ rateStructure: RateStructure) -> [Assignment] {
        let predicate = #Predicate<Assignment> { $0.rateStructure == rateStructure }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }
}
