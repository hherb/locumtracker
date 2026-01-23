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

/// Container for daily work sessions and earnings
@Model
public final class DailyRecord {
    public var id: UUID = UUID()
    public var assignmentId: UUID = UUID()
    public var date: Date = Date()
    public var totalEarnings: Double = 0
    public var subsidyEarnings: Double?
    public var notes: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        assignmentId: UUID,
        date: Date,
        notes: String? = nil
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.date = date
        self.totalEarnings = 0
        self.subsidyEarnings = nil
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// Represents an applied rate for transparency in invoicing
public struct AppliedRate: Codable, Sendable {
    public var sessionType: String
    public var rate: Double
    public var hours: Double
    public var amount: Double
    public var subsidyAmount: Double?

    public init(
        sessionType: String,
        rate: Double,
        hours: Double,
        amount: Double,
        subsidyAmount: Double? = nil
    ) {
        self.sessionType = sessionType
        self.rate = rate
        self.hours = hours
        self.amount = amount
        self.subsidyAmount = subsidyAmount
    }
}
