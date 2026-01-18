import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

/// Main content view displaying the list of assignments
///
/// Provides navigation to assignment details and actions to add new
/// locations and assignments. Uses SwiftData for persistence.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]
    @Query private var locations: [Location]

    @State private var showingAddAssignment = false
    @State private var showingAddLocation = false
    @State private var showingLocationList = false

    var body: some View {
        NavigationSplitView {
            assignmentList
                .navigationTitle("Assignments")
                .toolbar { toolbarContent }
                .sheet(isPresented: $showingAddLocation) {
                    AddLocationSheet(isPresented: $showingAddLocation)
                }
                .sheet(isPresented: $showingAddAssignment) {
                    AddAssignmentSheet(isPresented: $showingAddAssignment, locations: locations)
                }
                .sheet(isPresented: $showingLocationList) {
                    NavigationStack {
                        LocationListView()
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") {
                                        showingLocationList = false
                                    }
                                }
                            }
                    }
                }
        } detail: {
            if let selectedAssignment = assignments.first {
                AssignmentDetailView(assignment: selectedAssignment, locations: locations)
            } else {
                Text("Select an assignment")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationDestination(for: Assignment.self) { assignment in
            AssignmentDetailView(assignment: assignment, locations: locations)
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var assignmentList: some View {
        List {
            if assignments.isEmpty {
                emptyStateView
            } else {
                ForEach(assignments) { assignment in
                    NavigationLink(value: assignment) {
                        AssignmentRowView(assignment: assignment, locations: locations)
                    }
                }
                .onDelete(perform: deleteAssignments)
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Assignments", systemImage: "calendar.badge.plus")
        } description: {
            Text("Add your first assignment to get started.")
        } actions: {
            if locations.isEmpty {
                Button("Add Location First") {
                    showingAddLocation = true
                }
            } else {
                Button("Add Assignment") {
                    showingAddAssignment = true
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
        }
        #endif
        ToolbarItem {
            addMenu
        }
    }

    private var addMenu: some View {
        Menu {
            Button(action: { showingAddLocation = true }) {
                Label("Add Location", systemImage: "mappin.and.ellipse")
            }
            Button(action: { showingAddAssignment = true }) {
                Label("Add Assignment", systemImage: "calendar.badge.plus")
            }
            .disabled(locations.isEmpty)

            Divider()

            Button(action: { showingLocationList = true }) {
                Label("Manage Locations", systemImage: "map")
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
    }

    // MARK: - Actions

    /// Deletes assignments at the specified offsets
    /// - Parameter offsets: The index set of assignments to delete
    private func deleteAssignments(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(assignments[index])
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
        DailyRecord.self,
        Receipt.self,
        LocumProfile.self,
        QuarterlyQuota.self
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
        rateStructure: .dailyRate,
        dailyRate: 450.0,
        startDate: Date(),
        endDate: Date().addingTimeInterval(14 * secondsPerDay)
    )
    container.mainContext.insert(assignment)

    return ContentView()
        .modelContainer(container)
}
