import Foundation
import SwiftData
import LocumTrackerCore

/// Repository for Session model CRUD operations
public final class SessionRepository: Repository {
    public typealias Model = Session

    public let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Find By ID

    /// Finds a session by its UUID
    /// - Parameter id: The session ID
    /// - Returns: Session if found
    public func findById(_ id: UUID) -> Session? {
        let predicate = #Predicate<Session> { $0.id == id }
        return fetch(predicate: predicate, sortDescriptors: [], fetchLimit: 1).first
    }

    // MARK: - Specialized Queries

    /// Fetches sessions for a specific daily record
    /// - Parameter dailyRecordId: The daily record's UUID
    /// - Returns: Array of sessions sorted by start time
    public func fetchByDailyRecord(_ dailyRecordId: UUID) -> [Session] {
        let predicate = #Predicate<Session> { $0.dailyRecordId == dailyRecordId }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startTime, order: .forward)]
        )
    }

    /// Fetches sessions within a date range
    /// - Parameters:
    ///   - startDate: Start of range (inclusive)
    ///   - endDate: End of range (inclusive)
    /// - Returns: Array of sessions sorted by start time (newest first)
    public func fetchByDateRange(startDate: Date, endDate: Date) -> [Session] {
        let predicate = #Predicate<Session> {
            $0.startTime >= startDate && $0.startTime <= endDate
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startTime, order: .reverse)]
        )
    }

    /// Fetches sessions by MMM classification
    /// - Parameter mmmClassification: The MMM level (1-7)
    /// - Returns: Array of sessions at that MMM level
    public func fetchByMMMClassification(_ mmmClassification: Int) -> [Session] {
        let predicate = #Predicate<Session> { $0.mmmClassification == mmmClassification }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startTime, order: .reverse)]
        )
    }

    /// Fetches subsidy-eligible sessions (MMM 3-7)
    /// - Returns: Array of eligible sessions
    /// - Note: SwiftData predicates require compile-time literals for MMM range
    public func fetchSubsidyEligible() -> [Session] {
        let predicate = #Predicate<Session> {
            $0.mmmClassification >= 3 && $0.mmmClassification <= 7
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startTime, order: .reverse)]
        )
    }

    /// Fetches valid FPS sessions (3+ hours, MMM 3-7) within a date range
    /// - Parameters:
    ///   - startDate: Start of range
    ///   - endDate: End of range
    /// - Returns: Array of valid FPS sessions
    /// - Note: SwiftData predicates require compile-time literals for MMM range
    public func fetchValidFPSSessions(startDate: Date, endDate: Date) -> [Session] {
        let predicate = #Predicate<Session> {
            $0.startTime >= startDate &&
            $0.startTime <= endDate &&
            $0.mmmClassification >= 3 &&
            $0.mmmClassification <= 7
        }
        let dateRangeSessions = fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startTime, order: .forward)]
        )

        // Filter for minimum duration (computed property not available in predicate)
        return dateRangeSessions.filter { session in
            session.durationHours >= RuralSubsidyService.minimumSessionHours
        }
    }

    /// Fetches sessions by type
    /// - Parameter sessionType: The session type to filter by
    /// - Returns: Array of sessions of that type
    public func fetchByType(_ sessionType: SessionType) -> [Session] {
        let predicate = #Predicate<Session> { $0.sessionType == sessionType }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.startTime, order: .reverse)]
        )
    }
}
