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

/// Template for a default session, storing only time-of-day (no date).
/// Used to define typical work sessions at a location that can be applied
/// when creating new daily records.
public struct DefaultSessionTemplate: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var label: String?

    /// Creates a new session template.
    /// - Parameters:
    ///   - id: Unique identifier for the template
    ///   - startHour: Start hour (0-23)
    ///   - startMinute: Start minute (0-59)
    ///   - endHour: End hour (0-23)
    ///   - endMinute: End minute (0-59)
    ///   - label: Optional label for the session (e.g., "Morning Session")
    public init(
        id: UUID = UUID(),
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        label: String? = nil
    ) {
        self.id = id
        self.startHour = min(max(startHour, 0), 23)
        self.startMinute = min(max(startMinute, 0), 59)
        self.endHour = min(max(endHour, 0), 23)
        self.endMinute = min(max(endMinute, 0), 59)
        self.label = label
    }

    /// Duration of the session in hours.
    /// Returns 0 if end time is before start time.
    public var durationHours: Double {
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        let durationMinutes = endMinutes - startMinutes
        return durationMinutes > 0 ? Double(durationMinutes) / 60.0 : 0
    }

    /// Formatted time range string (e.g., "08:00 - 12:00")
    public var timeRangeFormatted: String {
        let startStr = String(format: "%02d:%02d", startHour, startMinute)
        let endStr = String(format: "%02d:%02d", endHour, endMinute)
        return "\(startStr) - \(endStr)"
    }

    /// Creates a Date object by combining this template's start time with a given date.
    /// - Parameter date: The date to combine with the start time
    /// - Returns: A Date with the template's start time on the given date
    public func startDate(on date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = startHour
        components.minute = startMinute
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    /// Creates a Date object by combining this template's end time with a given date.
    /// - Parameter date: The date to combine with the end time
    /// - Returns: A Date with the template's end time on the given date
    public func endDate(on date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = endHour
        components.minute = endMinute
        components.second = 0
        return calendar.date(from: components) ?? date
    }
}

// MARK: - Convenience Initializers

extension DefaultSessionTemplate {
    /// Creates a morning session template (8:00 - 12:00)
    public static func morningSession() -> DefaultSessionTemplate {
        DefaultSessionTemplate(
            startHour: 8,
            startMinute: 0,
            endHour: 12,
            endMinute: 0,
            label: "Morning"
        )
    }

    /// Creates an afternoon session template (13:00 - 17:00)
    public static func afternoonSession() -> DefaultSessionTemplate {
        DefaultSessionTemplate(
            startHour: 13,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            label: "Afternoon"
        )
    }
}
