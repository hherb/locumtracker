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

/// Protocol for building type-safe queries with a fluent API
public protocol QueryBuilder<Model> {
    associatedtype Model: PersistentModel

    /// Builds the final predicate from accumulated filters
    /// - Returns: Combined predicate or nil if no filters
    func buildPredicate() -> Predicate<Model>?

    /// Builds sort descriptors for the query
    /// - Returns: Array of sort descriptors
    func buildSortDescriptors() -> [SortDescriptor<Model>]

    /// Executes the query against a model context
    /// - Parameter context: The model context to query
    /// - Returns: Array of matching models
    func execute(in context: ModelContext) -> [Model]
}

/// Default implementation for query execution
public extension QueryBuilder {

    func execute(in context: ModelContext) -> [Model] {
        let descriptor = FetchDescriptor<Model>(
            predicate: buildPredicate(),
            sortBy: buildSortDescriptors()
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }
}
