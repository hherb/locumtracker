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

/// Represents a clinic or sub-location within an assignment where the doctor works.
/// Each location has its own Medicare provider number.
/// Stored as JSON in Assignment.providerLocationsJSON.
public struct ProviderLocation: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var providerNumber: String
    public var address: String?
    public var phone: String?
    public var notes: String?

    /// Creates a new provider location.
    /// - Parameters:
    ///   - id: Unique identifier for the location
    ///   - name: Name of the clinic or practice
    ///   - providerNumber: Medicare provider number for this location
    ///   - address: Optional street address
    ///   - phone: Optional phone number
    ///   - notes: Optional notes about this location
    public init(
        id: UUID = UUID(),
        name: String,
        providerNumber: String,
        address: String? = nil,
        phone: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.providerNumber = providerNumber
        self.address = address
        self.phone = phone
        self.notes = notes
    }

    /// Formatted display string combining name and provider number
    public var displayName: String {
        "\(name) (\(providerNumber))"
    }

    /// Whether this location has an address configured
    public var hasAddress: Bool {
        guard let address = address else { return false }
        return !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether this location has a phone number configured
    public var hasPhone: Bool {
        guard let phone = phone else { return false }
        return !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether this location has notes configured
    public var hasNotes: Bool {
        guard let notes = notes else { return false }
        return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
