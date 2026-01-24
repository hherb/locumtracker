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
import LocumTrackerUI

/// Detail view displaying full assignment information with edit and status management
struct AssignmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var assignment: Assignment
    let locations: [Location]

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    /// The location associated with this assignment
    private var location: Location? {
        locations.first { $0.id == assignment.locationId }
    }

    var body: some View {
        List {
            locationSection
            ratesSection
            datesSection
            sessionsSection
            statusSection
            actionsSection
        }
        .navigationTitle("Assignment Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAssignmentSheet(
                isPresented: $showingEditSheet,
                assignment: assignment,
                locations: locations
            )
        }
        .confirmationDialog(
            "Delete Assignment",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteAssignment()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this assignment? This action cannot be undone.")
        }
    }

    // MARK: - View Components

    private var locationSection: some View {
        Section("Location") {
            if let location = location {
                NavigationLink {
                    LocationDetailView(location: location)
                } label: {
                    VStack(alignment: .leading, spacing: DetailConstants.itemSpacing) {
                        Text(location.name)
                            .font(.headline)
                        Text(location.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            MMMBadge(classification: location.mmmClassification)
                            if location.isRuralSubsidyEligible {
                                Text("Subsidy Eligible")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(.vertical, DetailConstants.sectionVerticalPadding)
                }
            } else {
                Text("Unknown Location")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ratesSection: some View {
        Section("Rates") {
            LabeledContent("Rate Structure") {
                Text(assignment.rateStructure.description)
            }

            if assignment.rateStructure == .dailyRate {
                if let dailyRate = assignment.dailyRate {
                    LabeledContent("Daily Rate") {
                        Text(CurrencyFormatter.format(dailyRate))
                    }
                }
            } else {
                if let hourlyRate = assignment.hourlyRate {
                    LabeledContent("Hourly Rate") {
                        Text(CurrencyFormatter.format(hourlyRate))
                    }
                }
                if let onCallRate = assignment.onCallRate {
                    LabeledContent("On-Call Rate") {
                        Text(CurrencyFormatter.format(onCallRate) + "/hr")
                    }
                }
                if let callOutRate = assignment.callOutRate {
                    LabeledContent("Call-Out Rate") {
                        Text(CurrencyFormatter.format(callOutRate) + "/hr")
                    }
                }
            }
        }
    }

    private var datesSection: some View {
        Section("Schedule") {
            LabeledContent("Start Date") {
                Text(assignment.startDate, style: .date)
            }
            LabeledContent("End Date") {
                Text(assignment.endDate, style: .date)
            }
            LabeledContent("Duration") {
                Text(durationText)
            }
        }
    }

    private var sessionsSection: some View {
        Section("Sessions") {
            NavigationLink {
                SessionListView(assignment: assignment, location: location)
            } label: {
                LabeledContent("View Sessions") {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Text("Current Status")
                Spacer()
                StatusBadge(status: assignment.status)
            }

            if assignment.status != .cancelled && assignment.status != .completed {
                statusTransitionButtons
            }
        }
    }

    @ViewBuilder
    private var statusTransitionButtons: some View {
        switch assignment.status {
        case .planned:
            Button("Mark as Active") {
                updateStatus(to: .active)
            }
            .foregroundStyle(.green)
        case .active:
            Button("Mark as Completed") {
                updateStatus(to: .completed)
            }
            .foregroundStyle(.blue)
        case .completed, .cancelled:
            EmptyView()
        }
    }

    private var actionsSection: some View {
        Section {
            if assignment.status != .cancelled {
                Button("Cancel Assignment", role: .destructive) {
                    updateStatus(to: .cancelled)
                }
            }
            Button("Delete Assignment", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
    }

    /// Formatted duration text
    private var durationText: String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: assignment.startDate,
            to: assignment.endDate
        ).day ?? 0
        let actualDays = days + 1 // Include both start and end days
        return actualDays == 1 ? "1 day" : "\(actualDays) days"
    }

    // MARK: - Actions

    private func updateStatus(to newStatus: AssignmentStatus) {
        assignment.status = newStatus
        assignment.updatedAt = Date()
    }

    private func deleteAssignment() {
        modelContext.delete(assignment)
    }
}

// MARK: - Constants

private enum DetailConstants {
    static let itemSpacing: CGFloat = 4
    static let sectionVerticalPadding: CGFloat = 4
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([Location.self, Assignment.self])
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
        onCallRate: 37.50,
        startDate: Date(),
        endDate: Date().addingTimeInterval(14 * secondsPerDay),
        status: .active
    )
    container.mainContext.insert(assignment)

    return NavigationStack {
        AssignmentDetailView(assignment: assignment, locations: [location])
    }
    .modelContainer(container)
}
