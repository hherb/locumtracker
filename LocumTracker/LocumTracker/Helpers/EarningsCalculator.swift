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

/// Helper for recalculating earnings when sessions change
enum EarningsCalculator {

    /// Recalculates and updates the total earnings for a daily record
    /// based on its sessions and the assignment's rate structure.
    ///
    /// - Parameters:
    ///   - dailyRecord: The daily record to update
    ///   - assignment: The assignment containing rate configuration
    ///   - sessions: All sessions belonging to this daily record
    static func recalculateEarnings(
        for dailyRecord: DailyRecord,
        assignment: Assignment,
        sessions: [Session]
    ) {
        let sessionData = sessions.map { session in
            (type: session.sessionType, durationHours: session.durationHours)
        }

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: assignment.rateStructure,
            dailyRate: assignment.dailyRate,
            hourlyRate: assignment.hourlyRate,
            onCallRate: assignment.onCallRate,
            callOutRate: assignment.callOutRate,
            sessions: sessionData
        )

        dailyRecord.totalEarnings = earnings
        dailyRecord.updatedAt = Date()
    }

    /// Fetches all sessions for a daily record and recalculates earnings.
    ///
    /// - Parameters:
    ///   - dailyRecord: The daily record to update
    ///   - assignment: The assignment containing rate configuration
    ///   - modelContext: The SwiftData model context for querying sessions
    static func recalculateEarnings(
        for dailyRecord: DailyRecord,
        assignment: Assignment,
        in modelContext: ModelContext
    ) {
        let recordId = dailyRecord.id
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.dailyRecordId == recordId }
        )

        do {
            let sessions = try modelContext.fetch(descriptor)
            recalculateEarnings(for: dailyRecord, assignment: assignment, sessions: sessions)
        } catch {
            // If fetch fails, set earnings to 0
            dailyRecord.totalEarnings = 0
            dailyRecord.updatedAt = Date()
        }
    }
}
