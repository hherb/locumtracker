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

/// Main navigation providing access to all major sections of the app
///
/// Provides five sections:
/// - Assignments: Manage work assignments
/// - FPS Quota: Track WIP FPS session quota progress
/// - Earnings: View earnings dashboard
/// - Receipts: Track expense receipts
/// - Settings: User profile and app settings
///
/// Presented as a tab bar on iOS and a sidebar on macOS.
struct MainTabView: View {
    @State private var selectedTab: Tab = .assignments

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: Layout.sidebarMinWidth, ideal: Layout.sidebarIdealWidth)
        } detail: {
            tab(selectedTab)
                .id(selectedTab)
        }
        #else
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                self.tab(tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        #endif
    }

    /// Root view for a section
    /// - Parameter tab: The section to show
    /// - Returns: The section's navigation stack
    @ViewBuilder
    private func tab(_ tab: Tab) -> some View {
        switch tab {
        case .assignments:
            AssignmentsTab()
        case .quota:
            NavigationStack {
                QuarterlyQuotaView()
            }
        case .earnings:
            NavigationStack {
                EarningsDashboardView()
            }
        case .receipts:
            NavigationStack {
                ReceiptListView()
            }
        case .settings:
            NavigationStack {
                ProfileSettingsView()
            }
        }
    }

    /// Available sections in the main navigation
    enum Tab: CaseIterable, Identifiable {
        case assignments
        case quota
        case earnings
        case receipts
        case settings

        var id: Self { self }

        var title: String {
            switch self {
            case .assignments: return "Assignments"
            case .quota: return "FPS Quota"
            case .earnings: return "Earnings"
            case .receipts: return "Receipts"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .assignments: return "calendar"
            case .quota: return "chart.pie"
            case .earnings: return "chart.bar"
            case .receipts: return "receipt"
            case .settings: return "gearshape"
            }
        }
    }

    private enum Layout {
        static let sidebarMinWidth: CGFloat = 180
        static let sidebarIdealWidth: CGFloat = 200
    }
}

/// Tab content for assignments
///
/// Displays a list of assignments with ability to add, edit, and delete.
/// Also provides access to location management.
struct AssignmentsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]
    @Query private var locations: [Location]

    @State private var showingAddAssignment = false
    @State private var showingAddLocation = false
    @State private var showingLocationList = false

    var body: some View {
        NavigationStack {
            List {
                if assignments.isEmpty {
                    emptyStateView
                } else {
                    ForEach(assignments) { assignment in
                        NavigationLink(value: assignment.persistentModelID) {
                            AssignmentRowView(assignment: assignment, locations: locations)
                        }
                        .deleteContextMenu { modelContext.delete(assignment) }
                    }
                    .onDelete(perform: deleteAssignments)
                }
            }
            .navigationTitle("Assignments")
            .navigationDestination(for: PersistentIdentifier.self) { assignmentID in
                AssignmentDetailWrapper(assignmentID: assignmentID)
            }
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
        }
    }

    // MARK: - View Components

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

    /// Deletes assignments at the specified index offsets
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

    let receipt = Receipt(
        amount: 85.50,
        category: .meals,
        date: Date(),
        receiptDescription: "Lunch at hospital"
    )
    container.mainContext.insert(receipt)

    return MainTabView()
        .modelContainer(container)
}
