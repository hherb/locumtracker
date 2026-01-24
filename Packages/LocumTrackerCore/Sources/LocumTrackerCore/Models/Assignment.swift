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

    /// Medicare provider number for the main assignment location
    public var mainProviderNumber: String?

    /// JSON-encoded array of additional provider locations (clinics)
    public var providerLocationsJSON: Data?

    /// Additional provider locations (clinics) for this assignment.
    /// Each location has its own Medicare provider number.
    public var providerLocations: [ProviderLocation] {
        get {
            guard let data = providerLocationsJSON else { return [] }
            return (try? JSONDecoder().decode([ProviderLocation].self, from: data)) ?? []
        }
        set {
            providerLocationsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether this assignment has any provider locations configured
    public var hasProviderLocations: Bool {
        !providerLocations.isEmpty
    }

    /// Whether this assignment has a main provider number configured
    public var hasMainProviderNumber: Bool {
        guard let number = mainProviderNumber else { return false }
        return !number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
        status: AssignmentStatus = .planned
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
        self.createdAt = Date()
        self.updatedAt = Date()
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
}
