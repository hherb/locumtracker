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

/// Repository for LocumProfile model CRUD operations
public final class LocumProfileRepository: Repository {
    public typealias Model = LocumProfile

    public let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Find By ID

    /// Finds a profile by its UUID
    /// - Parameter id: The profile ID
    /// - Returns: LocumProfile if found
    public func findById(_ id: UUID) -> LocumProfile? {
        let predicate = #Predicate<LocumProfile> { $0.id == id }
        return fetch(predicate: predicate, sortDescriptors: [], fetchLimit: 1).first
    }

    // MARK: - Specialized Queries

    /// Fetches the current/primary profile
    /// Typically there should only be one profile per user
    /// - Returns: The most recently updated profile, or nil
    public func fetchCurrent() -> LocumProfile? {
        return fetch(
            predicate: nil,
            sortDescriptors: [SortDescriptor(\.updatedAt, order: .reverse)],
            fetchLimit: 1
        ).first
    }

    /// Fetches profiles by email
    /// - Parameter email: Email to search for
    /// - Returns: Array of profiles with that email
    public func fetchByEmail(_ email: String) -> [LocumProfile] {
        let predicate = #Predicate<LocumProfile> { $0.email == email }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
    }

    /// Fetches profiles that are GST registered
    /// - Returns: Array of GST-registered profiles
    public func fetchGSTRegistered() -> [LocumProfile] {
        let predicate = #Predicate<LocumProfile> { $0.gstRegistered == true }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.lastName, order: .forward)]
        )
    }

    /// Fetches profiles that are vocationally registered
    /// - Returns: Array of vocational profiles
    public func fetchVocational() -> [LocumProfile] {
        let predicate = #Predicate<LocumProfile> { $0.isVocational == true }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.lastName, order: .forward)]
        )
    }

    /// Fetches profiles with a valid ABN
    /// - Returns: Array of profiles with ABN set
    public func fetchWithABN() -> [LocumProfile] {
        let predicate = #Predicate<LocumProfile> { $0.abn != nil }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.lastName, order: .forward)]
        )
    }

    /// Fetches profiles by specialty
    /// - Parameter specialty: The specialty to filter by
    /// - Returns: Array of profiles with that specialty
    public func fetchBySpecialty(_ specialty: String) -> [LocumProfile] {
        let predicate = #Predicate<LocumProfile> { $0.specialty == specialty }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.lastName, order: .forward)]
        )
    }

    /// Creates or updates the primary profile
    /// - Parameter profile: The profile to save
    /// - Throws: RepositoryError if save fails
    public func saveProfile(_ profile: LocumProfile) throws {
        // Check if profile already exists
        if findById(profile.id) == nil {
            insert(profile)
        }
        profile.updatedAt = Date()
        try save()
    }
}
