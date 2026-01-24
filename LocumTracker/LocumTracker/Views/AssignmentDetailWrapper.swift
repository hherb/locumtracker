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

import SwiftUI
import SwiftData
import LocumTrackerCore

/// Wrapper view that fetches an Assignment by its persistent identifier
///
/// This wrapper solves SwiftData context detachment issues that occur when
/// passing model objects through navigation. By accepting only the identifier
/// and fetching the model within the view, we ensure the Assignment is always
/// properly attached to the current ModelContext.
struct AssignmentDetailWrapper: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var locations: [Location]

    let assignmentID: PersistentIdentifier

    /// Fetch the assignment from the model context using its persistent identifier
    private var assignment: Assignment? {
        modelContext.model(for: assignmentID) as? Assignment
    }

    var body: some View {
        if let assignment = assignment {
            AssignmentDetailView(assignment: assignment, locations: locations)
        } else {
            ContentUnavailableView(
                "Assignment Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("The assignment may have been deleted.")
            )
        }
    }
}

/// Wrapper view for SessionListView that fetches Assignment by ID
///
/// Ensures the Assignment is properly attached to the ModelContext before
/// passing it to SessionListView.
struct SessionListWrapper: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var locations: [Location]

    let assignmentID: PersistentIdentifier
    let locationID: UUID?

    /// Fetch the assignment from the model context using its persistent identifier
    private var assignment: Assignment? {
        modelContext.model(for: assignmentID) as? Assignment
    }

    /// Find the location by its UUID from the queried locations
    private var location: Location? {
        guard let locationID = locationID else { return nil }
        return locations.first { $0.id == locationID }
    }

    var body: some View {
        if let assignment = assignment {
            SessionListView(assignment: assignment, location: location)
        } else {
            ContentUnavailableView(
                "Assignment Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("The assignment may have been deleted.")
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([
        Location.self,
        Assignment.self,
        Session.self,
        DailyRecord.self
    ])
    let container = try! ModelContainer(for: schema, configurations: config)

    let location = Location(
        name: "Royal Darwin Hospital",
        address: "Rocklands Dr, Tiwi NT 0810",
        mmmClassification: 5
    )
    container.mainContext.insert(location)

    let secondsPerDay: TimeInterval = 86400
    let assignment = Assignment(
        locationId: location.id,
        rateStructure: .hourlyRate,
        hourlyRate: 150.0,
        startDate: Date(),
        endDate: Date().addingTimeInterval(14 * secondsPerDay),
        status: .active
    )
    container.mainContext.insert(assignment)

    return NavigationStack {
        AssignmentDetailWrapper(assignmentID: assignment.persistentModelID)
    }
    .modelContainer(container)
}
