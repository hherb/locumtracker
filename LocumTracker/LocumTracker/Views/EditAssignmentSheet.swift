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

    // Provider locations (clinics)
    @State private var mainProviderNumber: String
    @State private var providerLocations: [ProviderLocation]
    @State private var showingAddProviderLocation = false
    @State private var editingProviderLocationIndex: IdentifiableIndex?

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
        _mainProviderNumber = State(initialValue: assignment.mainProviderNumber ?? "")
        _providerLocations = State(initialValue: assignment.providerLocations)
    }

    var body: some View {
        NavigationStack {
            Form {
                locationSection
                providerNumbersSection
                rateSection
                dateSection
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
            .sheet(isPresented: $showingAddProviderLocation) {
                AddProviderLocationSheet(
                    isPresented: $showingAddProviderLocation,
                    providerLocations: $providerLocations
                )
            }
            .sheet(item: $editingProviderLocationIndex) { identifiableIndex in
                EditProviderLocationSheet(
                    isPresented: Binding(
                        get: { editingProviderLocationIndex != nil },
                        set: { if !$0 { editingProviderLocationIndex = nil } }
                    ),
                    providerLocations: $providerLocations,
                    editingIndex: identifiableIndex.index
                )
            }
        }
    }

    // MARK: - View Components

    private var locationSection: some View {
        Section("Location") {
            Picker("Location", selection: $selectedLocationId) {
                ForEach(locations) { location in
                    Text(location.name).tag(location.id)
                }
            }
        }
    }

    private var providerNumbersSection: some View {
        Section {
            TextField("Main Provider Number", text: $mainProviderNumber)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                #endif

            if !providerLocations.isEmpty {
                ForEach(Array(providerLocations.enumerated()), id: \.element.id) { index, providerLocation in
                    Button {
                        editingProviderLocationIndex = IdentifiableIndex(id: index)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(providerLocation.name)
                                    .fontWeight(.medium)
                                Text(providerLocation.providerNumber)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { indexSet in
                    providerLocations.remove(atOffsets: indexSet)
                }
            }

            Button {
                showingAddProviderLocation = true
            } label: {
                Label("Add Clinic", systemImage: "plus.circle")
            }
        } header: {
            Text("Provider Numbers")
        } footer: {
            Text("Add Medicare provider numbers for the main location and any additional clinics where you work during this assignment.")
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
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
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

        // Save provider numbers
        let trimmedMainNumber = mainProviderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        assignment.mainProviderNumber = trimmedMainNumber.isEmpty ? nil : trimmedMainNumber
        assignment.providerLocations = providerLocations

        isPresented = false
    }
}

// MARK: - Helper Types

/// Wrapper to make Int usable with sheet(item:)
private struct IdentifiableIndex: Identifiable {
    let id: Int
    var index: Int { id }
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
