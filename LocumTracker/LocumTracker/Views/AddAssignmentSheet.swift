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

/// Sheet view for adding a new assignment
struct AddAssignmentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    let locations: [Location]
    let preselectedLocationId: UUID?

    @State private var selectedLocationId: UUID?
    @State private var rateStructure: RateStructure = .dailyRate
    @State private var dailyRate: Double = AssignmentDefaults.dailyRate
    @State private var hourlyRate: Double = AssignmentDefaults.hourlyRate
    @State private var onCallRate: Double?
    @State private var callOutRate: Double?
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(AssignmentDefaults.defaultDurationDays)

    init(isPresented: Binding<Bool>, locations: [Location], preselectedLocationId: UUID? = nil) {
        self._isPresented = isPresented
        self.locations = locations
        self.preselectedLocationId = preselectedLocationId
    }

    /// Currently selected location
    private var selectedLocation: Location? {
        locations.first { $0.id == selectedLocationId }
    }

    var body: some View {
        NavigationStack {
            Form {
                locationSection
                rateSection
                dateSection
            }
            .navigationTitle("Add Assignment")
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
                        saveAssignment()
                    }
                    .disabled(selectedLocationId == nil)
                }
            }
            .onAppear {
                // Use preselected location if provided, otherwise use first location
                let initialLocationId = preselectedLocationId ?? locations.first?.id
                if selectedLocationId == nil, let locationId = initialLocationId,
                   let location = locations.first(where: { $0.id == locationId }) {
                    selectedLocationId = locationId
                    applyLocationDefaults(from: location)
                }
            }
            .onChange(of: selectedLocationId) { _, newId in
                if let newId = newId,
                   let location = locations.first(where: { $0.id == newId }) {
                    applyLocationDefaults(from: location)
                }
            }
        }
    }

    /// Apply default rates from a location to the form fields
    private func applyLocationDefaults(from location: Location) {
        // Apply daily rate if available
        if let defaultDaily = location.defaultDailyRate {
            dailyRate = defaultDaily
        }

        // Apply hourly rate if available
        if let defaultHourly = location.defaultHourlyRate {
            hourlyRate = defaultHourly
        }

        // Apply on-call and call-out rates if available
        onCallRate = location.defaultOnCallRate
        callOutRate = location.defaultCallOutRate

        // Set rate structure based on which defaults are available
        if location.defaultDailyRate != nil {
            rateStructure = .dailyRate
        } else if location.defaultHourlyRate != nil {
            rateStructure = .hourlyRate
        }
    }

    // MARK: - View Components

    private var locationSection: some View {
        Section("Location") {
            Picker("Location", selection: $selectedLocationId) {
                Text("Select a location").tag(nil as UUID?)
                ForEach(locations) { location in
                    Text(location.name).tag(location.id as UUID?)
                }
            }
            .accessibilityIdentifier("locationPicker")
        }
    }

    private var rateSection: some View {
        Section("Rate Structure") {
            Picker("Rate Type", selection: $rateStructure) {
                Text("Daily Rate").tag(RateStructure.dailyRate)
                Text("Hourly Rate").tag(RateStructure.hourlyRate)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("rateTypePicker")

            if rateStructure == .dailyRate {
                rateInputRow(label: "Daily Rate", value: $dailyRate, identifier: "dailyRateField")
            } else {
                rateInputRow(label: "Hourly Rate", value: $hourlyRate, identifier: "hourlyRateField")
                optionalRateInputRow(label: "On-Call Rate", value: $onCallRate, identifier: "onCallRateField")
                optionalRateInputRow(label: "Call-Out Rate", value: $callOutRate, identifier: "callOutRateField")
            }

            if selectedLocation?.hasDefaultRates == true {
                Text("Rates pre-filled from location defaults")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dateSection: some View {
        Section("Dates") {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                .accessibilityIdentifier("startDatePicker")
            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                .accessibilityIdentifier("endDatePicker")
        }
    }

    /// Creates a row for rate input with currency formatting
    /// - Parameters:
    ///   - label: The label text for the row
    ///   - value: Binding to the rate value
    ///   - identifier: Accessibility identifier for the text field
    /// - Returns: A view containing the label and text field
    private func rateInputRow(label: String, value: Binding<Double>, identifier: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("Rate", value: value, format: .currency(code: CurrencyDefaults.currencyCode))
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(identifier)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }

    /// Creates a row for optional rate input with currency formatting
    /// - Parameters:
    ///   - label: The label text for the row
    ///   - value: Binding to the optional rate value
    ///   - identifier: Accessibility identifier for the text field
    /// - Returns: A view containing the label and text field
    private func optionalRateInputRow(label: String, value: Binding<Double?>, identifier: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("Optional", value: value, format: .currency(code: CurrencyDefaults.currencyCode))
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(identifier)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }

    // MARK: - Actions

    private func saveAssignment() {
        guard let locationId = selectedLocationId else { return }

        let assignment = Assignment(
            locationId: locationId,
            rateStructure: rateStructure,
            dailyRate: rateStructure == .dailyRate ? dailyRate : nil,
            hourlyRate: rateStructure == .hourlyRate ? hourlyRate : nil,
            onCallRate: rateStructure == .hourlyRate ? onCallRate : nil,
            callOutRate: rateStructure == .hourlyRate ? callOutRate : nil,
            startDate: startDate,
            endDate: endDate
        )
        modelContext.insert(assignment)
        isPresented = false
    }
}

// MARK: - Constants

/// Default values for new assignments
private enum AssignmentDefaults {
    /// Default daily rate in AUD
    static let dailyRate: Double = 400.0
    /// Default hourly rate in AUD
    static let hourlyRate: Double = 100.0
    /// Default assignment duration in seconds (7 days)
    static let defaultDurationDays: TimeInterval = 7 * TimeConstants.secondsPerDay
}

/// Time-related constants
private enum TimeConstants {
    /// Number of seconds in one day
    static let secondsPerDay: TimeInterval = 86400
}

/// Currency formatting constants
private enum CurrencyDefaults {
    /// Australian Dollar currency code
    static let currencyCode = "AUD"
}

#Preview {
    let location = Location(name: "Test Hospital", address: "123 Test St", mmmClassification: 5)
    return AddAssignmentSheet(isPresented: .constant(true), locations: [location])
        .modelContainer(for: [Location.self, Assignment.self], inMemory: true)
}
