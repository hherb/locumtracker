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

/// Rate structure options for assignments
public enum RateStructure: String, CaseIterable, Codable {
    case dailyRate = "daily_rate"
    case hourlyRate = "hourly_rate"

    public var description: String {
        switch self {
        case .dailyRate: return "Daily Rate"
        case .hourlyRate: return "Hourly Rate"
        }
    }
}

/// Status of an assignment
public enum AssignmentStatus: String, CaseIterable, Codable {
    case planned = "planned"
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"

    public var description: String {
        switch self {
        case .planned: return "Planned"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

/// Represents a work assignment or contract with a healthcare facility
@Model
public final class Assignment {
    public var id: UUID = UUID()
    public var locationId: UUID = UUID()
    public var rateStructure: RateStructure = RateStructure.dailyRate
    public var dailyRate: Double?
    public var hourlyRate: Double?
    public var onCallRate: Double?
    public var callOutRate: Double?
    public var startDate: Date = Date()
    public var endDate: Date = Date()
    public var status: AssignmentStatus = AssignmentStatus.planned
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    // MARK: - Default Session Templates

    /// JSON-encoded default session templates for this assignment (stored as Data for SwiftData compatibility)
    public var defaultSessionTemplatesJSON: Data?

    // MARK: - Multi-Location Support

    /// JSON-encoded array of additional location IDs for this assignment
    public var additionalLocationIdsJSON: Data?

    /// Name for this assignment (e.g., "Darwin Remote Communities")
    public var name: String?

    /// Creates a new assignment.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - locationId: Primary location for this assignment
    ///   - rateStructure: Whether paid daily or hourly
    ///   - dailyRate: Daily rate amount (if daily rate structure)
    ///   - hourlyRate: Hourly rate amount (if hourly rate structure)
    ///   - onCallRate: On-call rate (typically 25% of hourly)
    ///   - callOutRate: Call-out rate (typically 50% of hourly)
    ///   - startDate: Assignment start date
    ///   - endDate: Assignment end date
    ///   - status: Current status of the assignment
    ///   - name: Optional name for the assignment
    ///   - defaultSessionTemplates: Default session times for this assignment
    ///   - additionalLocationIds: Additional locations besides the primary
    public init(
        id: UUID = UUID(),
        locationId: UUID,
        rateStructure: RateStructure,
        dailyRate: Double? = nil,
        hourlyRate: Double? = nil,
        onCallRate: Double? = nil,
        callOutRate: Double? = nil,
        startDate: Date,
        endDate: Date,
        status: AssignmentStatus = .planned,
        name: String? = nil,
        defaultSessionTemplates: [DefaultSessionTemplate] = [],
        additionalLocationIds: [UUID] = []
    ) {
        self.id = id
        self.locationId = locationId
        self.rateStructure = rateStructure
        self.dailyRate = dailyRate
        self.hourlyRate = hourlyRate
        self.onCallRate = onCallRate
        self.callOutRate = callOutRate
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()

        // Encode JSON fields
        if !defaultSessionTemplates.isEmpty {
            self.defaultSessionTemplatesJSON = try? JSONEncoder().encode(defaultSessionTemplates)
        }
        if !additionalLocationIds.isEmpty {
            self.additionalLocationIdsJSON = try? JSONEncoder().encode(additionalLocationIds)
        }
    }

    /// Returns date range for this assignment
    public var dateRange: ClosedRange<Date> {
        startDate...endDate
    }

    /// Validates that the assignment has consistent rate configuration
    public var hasValidRateConfiguration: Bool {
        switch rateStructure {
        case .dailyRate:
            return dailyRate != nil && dailyRate! > 0
        case .hourlyRate:
            return hourlyRate != nil && hourlyRate! > 0
        }
    }

    // MARK: - Session Templates Computed Properties

    /// Default session templates for this assignment.
    /// These are used when adding sessions, with location templates as fallback.
    public var defaultSessionTemplates: [DefaultSessionTemplate] {
        get {
            guard let data = defaultSessionTemplatesJSON else { return [] }
            return (try? JSONDecoder().decode([DefaultSessionTemplate].self, from: data)) ?? []
        }
        set {
            defaultSessionTemplatesJSON = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether this assignment has default session templates configured
    public var hasDefaultSessionTemplates: Bool {
        !defaultSessionTemplates.isEmpty
    }

    // MARK: - Multi-Location Computed Properties

    /// Additional locations associated with this assignment (besides the primary locationId).
    /// For assignments where the doctor visits multiple sites.
    public var additionalLocationIds: [UUID] {
        get {
            guard let data = additionalLocationIdsJSON else { return [] }
            return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
        }
        set {
            additionalLocationIdsJSON = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }

    /// All location IDs for this assignment (primary + additional)
    public var allLocationIds: [UUID] {
        [locationId] + additionalLocationIds
    }

    /// Whether this assignment has multiple locations
    public var hasMultipleLocations: Bool {
        !additionalLocationIds.isEmpty
    }
}
