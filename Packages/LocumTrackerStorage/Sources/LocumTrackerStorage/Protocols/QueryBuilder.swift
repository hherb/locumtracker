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
