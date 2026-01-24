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

/// Sheet view for editing an existing assignment
struct EditAssignmentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @Bindable var assignment: Assignment
    let locations: [Location]

    @State private var selectedLocationId: UUID
    @State private var rateStructure: RateStructure
    @State private var dailyRate: Double
    @State private var hourlyRate: Double
    @State private var onCallRate: Double
    @State private var callOutRate: Double
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var status: AssignmentStatus
    @State private var assignmentName: String
    @State private var sessionTemplates: [DefaultSessionTemplate]
    @State private var additionalLocationIds: Set<UUID>
    @State private var showingTemplateEditor: Bool = false

    init(isPresented: Binding<Bool>, assignment: Assignment, locations: [Location]) {
        self._isPresented = isPresented
        self.assignment = assignment
        self.locations = locations

        // Initialize state from assignment
        _selectedLocationId = State(initialValue: assignment.locationId)
        _rateStructure = State(initialValue: assignment.rateStructure)
        _dailyRate = State(initialValue: assignment.dailyRate ?? EditDefaults.dailyRate)
        _hourlyRate = State(initialValue: assignment.hourlyRate ?? EditDefaults.hourlyRate)
        _onCallRate = State(initialValue: assignment.onCallRate ?? EditDefaults.onCallRate)
        _callOutRate = State(initialValue: assignment.callOutRate ?? EditDefaults.callOutRate)
        _startDate = State(initialValue: assignment.startDate)
        _endDate = State(initialValue: assignment.endDate)
        _status = State(initialValue: assignment.status)
        _assignmentName = State(initialValue: assignment.name ?? "")
        _sessionTemplates = State(initialValue: assignment.defaultSessionTemplates)
        _additionalLocationIds = State(initialValue: Set(assignment.additionalLocationIds))
    }

    /// The primary location for the assignment
    private var primaryLocation: Location? {
        locations.first { $0.id == selectedLocationId }
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                locationSection
                additionalLocationsSection
                rateSection
                dateSection
                sessionTemplatesSection
                statusSection
            }
            .navigationTitle("Edit Assignment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }

    // MARK: - View Components

    private var nameSection: some View {
        Section("Assignment Name") {
            TextField("Optional name (e.g., Darwin Remote Communities)", text: $assignmentName)
        }
    }

    private var locationSection: some View {
        Section("Primary Location") {
            Picker("Location", selection: $selectedLocationId) {
                ForEach(locations) { location in
                    Text(location.name).tag(location.id)
                }
            }

            if let primary = primaryLocation {
                LabeledContent("MMM Classification") {
                    MMMBadge(classification: primary.mmmClassification)
                }
            }
        }
    }

    private var additionalLocationsSection: some View {
        Section {
            ForEach(locations.filter { $0.id != selectedLocationId }) { location in
                Toggle(isOn: Binding(
                    get: { additionalLocationIds.contains(location.id) },
                    set: { isSelected in
                        if isSelected {
                            additionalLocationIds.insert(location.id)
                        } else {
                            additionalLocationIds.remove(location.id)
                        }
                    }
                )) {
                    HStack {
                        Text(location.name)
                        Spacer()
                        MMMBadge(classification: location.mmmClassification)
                    }
                }
            }
        } header: {
            Text("Additional Locations")
        } footer: {
            Text("Select other locations visited during this assignment (e.g., remote communities)")
        }
    }

    private var rateSection: some View {
        Section("Rate Structure") {
            Picker("Rate Type", selection: $rateStructure) {
                Text("Daily Rate").tag(RateStructure.dailyRate)
                Text("Hourly Rate").tag(RateStructure.hourlyRate)
            }
            .pickerStyle(.segmented)

            if rateStructure == .dailyRate {
                rateInputRow(label: "Daily Rate", value: $dailyRate)
            } else {
                rateInputRow(label: "Hourly Rate", value: $hourlyRate)
                rateInputRow(label: "On-Call Rate", value: $onCallRate)
                rateInputRow(label: "Call-Out Rate", value: $callOutRate)
            }
        }
    }

    private var dateSection: some View {
        Section("Dates") {
            DateRangePicker(
                startLabel: "Start Date",
                endLabel: "End Date",
                startDate: $startDate,
                endDate: $endDate
            )
        }
    }

    private var sessionTemplatesSection: some View {
        Section {
            if sessionTemplates.isEmpty {
                Button {
                    showingTemplateEditor = true
                } label: {
                    Label("Add Default Session Times", systemImage: "clock.badge.plus")
                }

                // Option to copy from location
                if let location = primaryLocation, location.hasDefaultSessionTemplates {
                    Button {
                        sessionTemplates = location.defaultSessionTemplates
                    } label: {
                        Label("Copy from Location", systemImage: "doc.on.doc")
                    }
                }

                // Quick add standard templates
                Button {
                    sessionTemplates = [
                        .morningSession(),
                        .afternoonSession()
                    ]
                } label: {
                    Label("Add Morning & Afternoon", systemImage: "sun.and.horizon")
                }
            } else {
                ForEach(sessionTemplates) { template in
                    HStack {
                        if let label = template.label {
                            Text(label)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Text(template.timeRangeFormatted)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indices in
                    sessionTemplates.remove(atOffsets: indices)
                }

                Button {
                    showingTemplateEditor = true
                } label: {
                    Label("Add Another Session", systemImage: "plus")
                }
            }
        } header: {
            Text("Default Sessions")
        } footer: {
            Text("Session templates are used when quickly adding sessions to this assignment")
        }
        .sheet(isPresented: $showingTemplateEditor) {
            SessionTemplateEditorView(templates: $sessionTemplates)
        }
    }

    private var statusSection: some View {
        Section("Status") {
            Picker("Status", selection: $status) {
                ForEach(AssignmentStatus.allCases, id: \.self) { status in
                    Text(status.description).tag(status)
                }
            }
        }
    }

    /// Creates a row for rate input with currency formatting
    private func rateInputRow(label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("Rate", value: value, format: .currency(code: CurrencyConstants.currencyCode))
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        assignment.locationId = selectedLocationId
        assignment.rateStructure = rateStructure
        assignment.startDate = startDate
        assignment.endDate = endDate
        assignment.status = status
        assignment.name = assignmentName.isEmpty ? nil : assignmentName
        assignment.defaultSessionTemplates = sessionTemplates
        assignment.additionalLocationIds = Array(additionalLocationIds)
        assignment.updatedAt = Date()

        if rateStructure == .dailyRate {
            assignment.dailyRate = dailyRate
            assignment.hourlyRate = nil
            assignment.onCallRate = nil
            assignment.callOutRate = nil
        } else {
            assignment.dailyRate = nil
            assignment.hourlyRate = hourlyRate
            assignment.onCallRate = onCallRate > 0 ? onCallRate : nil
            assignment.callOutRate = callOutRate > 0 ? callOutRate : nil
        }

        isPresented = false
    }
}

// MARK: - Constants

private enum EditDefaults {
    static let dailyRate: Double = 400.0
    static let hourlyRate: Double = 100.0
    static let onCallRate: Double = 25.0
    static let callOutRate: Double = 50.0
}

private enum CurrencyConstants {
    static let currencyCode = "AUD"
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([Location.self, Assignment.self])
    let container = try! ModelContainer(for: schema, configurations: config)

    let location = Location(
        name: "Cooktown Hospital",
        address: "123 Main St, Cooktown QLD",
        mmmClassification: 6
    )
    container.mainContext.insert(location)

    let secondsPerDay: TimeInterval = 86400
    let assignment = Assignment(
        locationId: location.id,
        rateStructure: .dailyRate,
        dailyRate: 450.0,
        startDate: Date(),
        endDate: Date().addingTimeInterval(7 * secondsPerDay)
    )
    container.mainContext.insert(assignment)

    return EditAssignmentSheet(
        isPresented: .constant(true),
        assignment: assignment,
        locations: [location]
    )
    .modelContainer(container)
}
