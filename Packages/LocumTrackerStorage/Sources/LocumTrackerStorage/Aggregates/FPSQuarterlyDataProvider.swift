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

/// Session data with related entities for FPS calculations
/// Note: Not Sendable because SwiftData models are not Sendable
public struct FPSSessionData {
    public let session: Session
    public let dailyRecord: DailyRecord
    public let assignment: Assignment
    public let location: Location

    /// The effective MMM classification for this session
    public var effectiveMMM: Int {
        session.mmmClassification
    }

    /// Whether this session is subsidy-eligible
    public var isEligible: Bool {
        session.isSubsidyEligible
    }

    public init(
        session: Session,
        dailyRecord: DailyRecord,
        assignment: Assignment,
        location: Location
    ) {
        self.session = session
        self.dailyRecord = dailyRecord
        self.assignment = assignment
        self.location = location
    }
}

/// Summary of quarterly FPS quota status
public struct QuotaSummary: Sendable {
    /// Default MMM classification when no sessions exist (lowest subsidy-eligible)
    private static let defaultMMMClassification = 3

    public let quarterStart: Date
    public let totalRawSessions: Int
    public let totalValidSessions: Int
    public let countedSessions: Int
    public let sessionsByMMM: [Int: Int]
    public let quotaMet: Bool

    /// Progress percentage toward minimum quota (21 sessions)
    public var progressPercentage: Double {
        Double(countedSessions) / Double(QuarterlyQuota.minimumSessions) * 100
    }

    /// Sessions remaining to meet minimum quota
    public var sessionsRemaining: Int {
        max(0, QuarterlyQuota.minimumSessions - countedSessions)
    }

    /// The MMM classification with most sessions
    public var predominantMMM: Int {
        sessionsByMMM.max { $0.value < $1.value }?.key ?? Self.defaultMMMClassification
    }

    public init(
        quarterStart: Date,
        totalRawSessions: Int,
        totalValidSessions: Int,
        countedSessions: Int,
        sessionsByMMM: [Int: Int],
        quotaMet: Bool
    ) {
        self.quarterStart = quarterStart
        self.totalRawSessions = totalRawSessions
        self.totalValidSessions = totalValidSessions
        self.countedSessions = countedSessions
        self.sessionsByMMM = sessionsByMMM
        self.quotaMet = quotaMet
    }
}

/// Aggregates session data for WIP FPS quota calculations
/// Handles cross-model queries that span Sessions, DailyRecords, and Assignments
public struct FPSQuarterlyDataProvider {

    private let modelContext: ModelContext
    private let sessionRepository: SessionRepository
    private let dailyRecordRepository: DailyRecordRepository
    private let assignmentRepository: AssignmentRepository
    private let locationRepository: LocationRepository

    /// Creates a new FPS data provider
    /// - Parameter modelContext: The model context to use for queries
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.sessionRepository = SessionRepository(modelContext: modelContext)
        self.dailyRecordRepository = DailyRecordRepository(modelContext: modelContext)
        self.assignmentRepository = AssignmentRepository(modelContext: modelContext)
        self.locationRepository = LocationRepository(modelContext: modelContext)
    }

    // MARK: - Quarter Data

    /// Fetches all valid FPS sessions for a quarter with related data
    /// - Parameter quarterStart: First day of the quarter
    /// - Returns: Array of FPSSessionData with related entities
    public func fetchQuarterSessions(quarterStart: Date) -> [FPSSessionData] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .quarter, for: quarterStart) else {
            return []
        }

        let sessions = SessionQueryBuilder()
            .dateRange(from: interval.start, to: interval.end)
            .fpsValid()
            .sortByStartTime(.forward)
            .execute(in: modelContext)

        return sessions.compactMap { session -> FPSSessionData? in
            // Find related daily record
            guard let dailyRecord = dailyRecordRepository.findById(session.dailyRecordId) else {
                return nil
            }

            // Find related assignment
            guard let assignment = assignmentRepository.findById(dailyRecord.assignmentId) else {
                return nil
            }

            // Find related location
            guard let location = locationRepository.findById(assignment.locationId) else {
                return nil
            }

            return FPSSessionData(
                session: session,
                dailyRecord: dailyRecord,
                assignment: assignment,
                location: location
            )
        }
    }

    /// Fetches valid FPS sessions for the current quarter
    /// - Returns: Array of FPSSessionData
    public func fetchCurrentQuarterSessions() -> [FPSSessionData] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .quarter, for: Date()) else {
            return []
        }
        return fetchQuarterSessions(quarterStart: interval.start)
    }

    /// Calculates quarterly quota summary
    /// - Parameter quarterStart: First day of the quarter
    /// - Returns: QuotaSummary with session counts by MMM
    public func calculateQuotaSummary(quarterStart: Date) -> QuotaSummary {
        let sessionData = fetchQuarterSessions(quarterStart: quarterStart)

        // Group sessions by date and apply 2-per-day cap
        let calendar = Calendar.current
        var sessionsByDate: [Date: [FPSSessionData]] = [:]

        for data in sessionData {
            let day = calendar.startOfDay(for: data.session.startTime)
            sessionsByDate[day, default: []].append(data)
        }

        // Count valid sessions (max 2 per day)
        var mmmCounts: [Int: Int] = [3: 0, 4: 0, 5: 0, 6: 0, 7: 0]
        var totalValidSessions = 0

        for (_, daySessions) in sessionsByDate {
            // Sort by start time and take first 2
            let sortedSessions = daySessions.sorted { $0.session.startTime < $1.session.startTime }
            let validForDay = sortedSessions.prefix(RuralSubsidyService.maximumSessionsPerDay)

            for data in validForDay {
                let mmm = data.session.mmmClassification
                mmmCounts[mmm, default: 0] += 1
                totalValidSessions += 1
            }
        }

        let countedSessions = RuralSubsidyService.countedSessionsForQuarter(totalValidSessions)

        return QuotaSummary(
            quarterStart: quarterStart,
            totalRawSessions: sessionData.count,
            totalValidSessions: totalValidSessions,
            countedSessions: countedSessions,
            sessionsByMMM: mmmCounts,
            quotaMet: RuralSubsidyService.isActiveQuarter(sessions: countedSessions)
        )
    }

    /// Calculates quota summary for the current quarter
    /// - Returns: QuotaSummary for current quarter
    public func calculateCurrentQuotaSummary() -> QuotaSummary {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .quarter, for: Date()) else {
            return QuotaSummary(
                quarterStart: Date(),
                totalRawSessions: 0,
                totalValidSessions: 0,
                countedSessions: 0,
                sessionsByMMM: [:],
                quotaMet: false
            )
        }
        return calculateQuotaSummary(quarterStart: interval.start)
    }

    // MARK: - Multi-Quarter Analysis

    /// Calculates quota summaries for multiple quarters
    /// - Parameters:
    ///   - count: Number of quarters to analyze
    ///   - endingAt: End date (defaults to current quarter)
    /// - Returns: Array of QuotaSummary, newest first
    public func calculateQuotaSummaries(count: Int, endingAt: Date = Date()) -> [QuotaSummary] {
        let calendar = Calendar.current
        var summaries: [QuotaSummary] = []
        var currentDate = endingAt

        for _ in 0..<count {
            guard let quarterInterval = calendar.dateInterval(of: .quarter, for: currentDate) else {
                break
            }

            let summary = calculateQuotaSummary(quarterStart: quarterInterval.start)
            summaries.append(summary)

            // Move to previous quarter
            currentDate = calendar.date(byAdding: .day, value: -1, to: quarterInterval.start) ?? currentDate
        }

        return summaries
    }

    /// Counts active quarters in a reference period
    /// - Parameters:
    ///   - quarters: Number of quarters to check
    ///   - endingAt: End date of reference period
    /// - Returns: Number of active quarters
    public func countActiveQuarters(_ quarters: Int, endingAt: Date = Date()) -> Int {
        let summaries = calculateQuotaSummaries(count: quarters, endingAt: endingAt)
        return summaries.filter { $0.quotaMet }.count
    }
}
