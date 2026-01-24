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

/// Repository for Location model CRUD operations
public final class LocationRepository: Repository {
    public typealias Model = Location

    public let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Find By ID

    /// Finds a location by its UUID
    /// - Parameter id: The location ID
    /// - Returns: Location if found
    public func findById(_ id: UUID) -> Location? {
        let predicate = #Predicate<Location> { $0.id == id }
        return fetch(predicate: predicate, sortDescriptors: [], fetchLimit: 1).first
    }

    // MARK: - Specialized Queries

    /// Fetches locations by MMM classification
    /// - Parameter mmmClassification: The MMM level (1-7)
    /// - Returns: Array of locations at that MMM level
    public func fetchByMMMClassification(_ mmmClassification: Int) -> [Location] {
        let predicate = #Predicate<Location> { $0.mmmClassification == mmmClassification }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.name, order: .forward)]
        )
    }

    /// Fetches subsidy-eligible locations (MMM 3-7)
    /// - Returns: Array of eligible locations sorted by name
    /// - Note: SwiftData predicates require compile-time literals for MMM range
    public func fetchSubsidyEligible() -> [Location] {
        let predicate = #Predicate<Location> {
            $0.mmmClassification >= 3 && $0.mmmClassification <= 7
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.name, order: .forward)]
        )
    }

    /// Fetches metropolitan locations (MMM 1-2)
    /// - Returns: Array of metropolitan locations sorted by name
    /// - Note: SwiftData predicates require compile-time literals for MMM range
    public func fetchMetropolitan() -> [Location] {
        let predicate = #Predicate<Location> {
            $0.mmmClassification >= 1 && $0.mmmClassification <= 2
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.name, order: .forward)]
        )
    }

    /// Fetches locations by name search
    /// - Parameter searchText: Text to search for in location names
    /// - Returns: Array of matching locations
    public func fetchByName(_ searchText: String) -> [Location] {
        let predicate = #Predicate<Location> {
            $0.name.localizedStandardContains(searchText)
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.name, order: .forward)]
        )
    }

    /// Fetches all locations sorted by name
    /// - Returns: Array of all locations
    public func fetchAllSorted() -> [Location] {
        fetch(
            predicate: nil,
            sortDescriptors: [SortDescriptor(\.name, order: .forward)]
        )
    }

    /// Fetches currently effective locations
    /// - Parameter referenceDate: Date to check effectiveness (defaults to now)
    /// - Returns: Array of locations effective at the reference date
    public func fetchEffective(at referenceDate: Date = Date()) -> [Location] {
        let predicate = #Predicate<Location> {
            $0.effectiveFrom <= referenceDate &&
            ($0.effectiveTo == nil || $0.effectiveTo! >= referenceDate)
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.name, order: .forward)]
        )
    }

    /// Fetches locations with coordinates
    /// - Returns: Array of locations that have latitude and longitude set
    public func fetchWithCoordinates() -> [Location] {
        let predicate = #Predicate<Location> {
            $0.latitude != nil && $0.longitude != nil
        }
        return fetch(
            predicate: predicate,
            sortDescriptors: [SortDescriptor(\.name, order: .forward)]
        )
    }
}
