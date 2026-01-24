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

/// Errors that can occur during repository operations
public enum RepositoryError: Error, Sendable {
    case notFound(id: UUID)
    case saveFailure(underlying: Error)
    case deleteFailure(underlying: Error)
    case invalidState(message: String)
}

/// Generic repository protocol for CRUD operations on SwiftData models
public protocol Repository<Model> {
    associatedtype Model: PersistentModel

    /// The model context used for persistence operations
    var modelContext: ModelContext { get }

    // MARK: - Create

    /// Inserts a new model into the context
    /// - Parameter model: The model instance to insert
    func insert(_ model: Model)

    /// Inserts multiple models in a batch
    /// - Parameter models: Array of model instances to insert
    func insertBatch(_ models: [Model])

    // MARK: - Read

    /// Fetches a model by its ID
    /// - Parameter id: The UUID of the model
    /// - Returns: The model if found, nil otherwise
    func findById(_ id: UUID) -> Model?

    /// Fetches all models of this type
    /// - Returns: Array of all models
    func fetchAll() -> [Model]

    /// Fetches models matching a predicate
    /// - Parameters:
    ///   - predicate: The filter predicate
    ///   - sortDescriptors: Optional sort descriptors
    ///   - fetchLimit: Optional limit on number of results
    /// - Returns: Array of matching models
    func fetch(
        predicate: Predicate<Model>?,
        sortDescriptors: [SortDescriptor<Model>],
        fetchLimit: Int?
    ) -> [Model]

    // MARK: - Update

    /// Saves pending changes in the context
    /// - Throws: RepositoryError.saveFailure if save fails
    func save() throws

    // MARK: - Delete

    /// Deletes a model from the context
    /// - Parameter model: The model to delete
    func delete(_ model: Model)

    /// Deletes a model by ID
    /// - Parameter id: The UUID of the model to delete
    /// - Returns: True if model was found and deleted
    @discardableResult
    func deleteById(_ id: UUID) -> Bool

    /// Deletes multiple models in a batch
    /// - Parameter models: Array of models to delete
    func deleteBatch(_ models: [Model])

    // MARK: - Count

    /// Counts models matching an optional predicate
    /// - Parameter predicate: Optional filter predicate
    /// - Returns: Number of matching models
    func count(predicate: Predicate<Model>?) -> Int
}

// MARK: - Default Implementations

public extension Repository {

    func insert(_ model: Model) {
        modelContext.insert(model)
    }

    func insertBatch(_ models: [Model]) {
        for model in models {
            modelContext.insert(model)
        }
    }

    func fetchAll() -> [Model] {
        fetch(predicate: nil, sortDescriptors: [], fetchLimit: nil)
    }

    func fetch(
        predicate: Predicate<Model>?,
        sortDescriptors: [SortDescriptor<Model>] = [],
        fetchLimit: Int? = nil
    ) -> [Model] {
        var descriptor = FetchDescriptor<Model>(predicate: predicate, sortBy: sortDescriptors)
        if let limit = fetchLimit {
            descriptor.fetchLimit = limit
        }

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailure(underlying: error)
        }
    }

    func delete(_ model: Model) {
        modelContext.delete(model)
    }

    func deleteBatch(_ models: [Model]) {
        for model in models {
            modelContext.delete(model)
        }
    }

    func deleteById(_ id: UUID) -> Bool {
        if let model = findById(id) {
            delete(model)
            return true
        }
        return false
    }

    func count(predicate: Predicate<Model>? = nil) -> Int {
        let descriptor = FetchDescriptor<Model>(predicate: predicate)
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            return 0
        }
    }
}
