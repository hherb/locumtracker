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

/// Detail view for viewing and editing a location
struct LocationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var location: Location
    @Query private var assignments: [Assignment]

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    /// Assignments at this location
    private var locationAssignments: [Assignment] {
        assignments.filter { $0.locationId == location.id }
    }

    var body: some View {
        List {
            detailsSection
            defaultRatesSection
            defaultSessionsSection
            subsidySection
            assignmentsSection
            actionsSection
        }
        .navigationTitle(location.name)
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
            EditLocationSheet(isPresented: $showingEditSheet, location: location)
        }
        .confirmationDialog(
            "Delete Location",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteLocation()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if locationAssignments.isEmpty {
                Text("Are you sure you want to delete this location?")
            } else {
                Text("This location has \(locationAssignments.count) assignment(s). Deleting it will remove the location reference from those assignments.")
            }
        }
    }

    // MARK: - View Components

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Name") {
                Text(location.name)
            }
            LabeledContent("Address") {
                Text(location.address)
            }
            if let phoneNumber = location.phoneNumber {
                LabeledContent("Phone") {
                    Text(phoneNumber)
                }
            }
            if let providerNumber = location.providerNumber {
                LabeledContent("Provider Number") {
                    Text(providerNumber)
                }
            }
            HStack {
                Text("MMM Classification")
                Spacer()
                MMMBadge(classification: location.mmmClassification)
            }
            if let notes = location.notes {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(notes)
                }
            }
        }
    }

    @ViewBuilder
    private var defaultRatesSection: some View {
        if location.hasDefaultRates {
            Section("Default Rates") {
                if let dailyRate = location.defaultDailyRate {
                    LabeledContent("Daily Rate") {
                        Text(CurrencyFormatter.format(dailyRate))
                    }
                }
                if let hourlyRate = location.defaultHourlyRate {
                    LabeledContent("Hourly Rate") {
                        Text(CurrencyFormatter.format(hourlyRate) + "/hr")
                    }
                }
                if let onCallRate = location.defaultOnCallRate {
                    LabeledContent("On-Call Rate") {
                        Text(CurrencyFormatter.format(onCallRate) + "/hr")
                    }
                }
                if let callOutRate = location.defaultCallOutRate {
                    LabeledContent("Call-Out Rate") {
                        Text(CurrencyFormatter.format(callOutRate) + "/hr")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var defaultSessionsSection: some View {
        if location.hasDefaultSessionTemplates {
            Section("Default Sessions") {
                ForEach(location.defaultSessionTemplates) { template in
                    HStack {
                        if let label = template.label {
                            Text(label)
                                .fontWeight(.medium)
                        } else {
                            Text("Session")
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Text(template.timeRangeFormatted)
                            .foregroundStyle(.secondary)
                        Text("(\(String(format: "%.1f", template.durationHours))h)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var subsidySection: some View {
        Section("WIP Doctor Stream (FPS)") {
            if location.isRuralSubsidyEligible {
                let vrPayment = RuralSubsidyService.getAnnualPayment(
                    yearLevel: 1,
                    mmmClassification: location.mmmClassification,
                    registrationStatus: .vocationallyRegistered
                )
                let nonVRPayment = RuralSubsidyService.getAnnualPayment(
                    yearLevel: 1,
                    mmmClassification: location.mmmClassification,
                    registrationStatus: .nonVocational
                )

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Eligible for WIP incentive payments")
                }

                LabeledContent("Year 1 (VR/Training)") {
                    Text(CurrencyFormatter.format(vrPayment) + "/year")
                        .foregroundStyle(.green)
                }

                LabeledContent("Year 1 (Non-VR)") {
                    Text(CurrencyFormatter.format(nonVRPayment) + "/year")
                        .foregroundStyle(.green)
                }

                Text("Requires 21+ sessions (3+ hours each) per quarter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("Not eligible for WIP incentive")
                }
                Text("Only MMM3-7 locations qualify for WIP Doctor Stream payments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var assignmentsSection: some View {
        Section("Assignments") {
            if locationAssignments.isEmpty {
                Text("No assignments at this location")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(locationAssignments) { assignment in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(formatDateRange(assignment.startDate, assignment.endDate))
                                .font(.subheadline)
                            Text(assignment.status.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(status: assignment.status)
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Delete Location", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
    }

    // MARK: - Helpers

    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func deleteLocation() {
        modelContext.delete(location)
    }
}

// MARK: - Edit Location Sheet

/// Sheet view for editing an existing location
struct EditLocationSheet: View {
    @Binding var isPresented: Bool
    @Bindable var location: Location

    @State private var name: String
    @State private var address: String
    @State private var phoneNumber: String
    @State private var providerNumber: String
    @State private var notes: String
    @State private var mmmClassification: Int

    // Default rates
    @State private var defaultDailyRate: String
    @State private var defaultHourlyRate: String
    @State private var defaultOnCallRate: String
    @State private var defaultCallOutRate: String

    // Default session templates
    @State private var defaultSessionTemplates: [DefaultSessionTemplate]
    @State private var showingAddSessionTemplate = false

    init(isPresented: Binding<Bool>, location: Location) {
        self._isPresented = isPresented
        self.location = location
        _name = State(initialValue: location.name)
        _address = State(initialValue: location.address)
        _phoneNumber = State(initialValue: location.phoneNumber ?? "")
        _providerNumber = State(initialValue: location.providerNumber ?? "")
        _notes = State(initialValue: location.notes ?? "")
        _mmmClassification = State(initialValue: location.mmmClassification)

        // Initialize rates from location (convert Double? to String)
        _defaultDailyRate = State(initialValue: location.defaultDailyRate.map { String($0) } ?? "")
        _defaultHourlyRate = State(initialValue: location.defaultHourlyRate.map { String($0) } ?? "")
        _defaultOnCallRate = State(initialValue: location.defaultOnCallRate.map { String($0) } ?? "")
        _defaultCallOutRate = State(initialValue: location.defaultCallOutRate.map { String($0) } ?? "")

        _defaultSessionTemplates = State(initialValue: location.defaultSessionTemplates)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location Details") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                Section("Medicare") {
                    TextField("Provider Number", text: $providerNumber)
                        .textInputAutocapitalization(.characters)
                }

                Section("MMM Classification") {
                    Picker("MMM Level", selection: $mmmClassification) {
                        ForEach(EditConstants.classificationRange, id: \.self) { level in
                            Text("MMM\(level)").tag(level)
                        }
                    }
                    Text(mmmDescription(for: mmmClassification))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                defaultRatesSection
                defaultSessionsSection
            }
            .navigationTitle("Edit Location")
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
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddSessionTemplate) {
                EditAddSessionTemplateSheet(
                    isPresented: $showingAddSessionTemplate,
                    templates: $defaultSessionTemplates
                )
            }
        }
    }

    // MARK: - Default Rates Section

    private var defaultRatesSection: some View {
        Section {
            HStack {
                Text("Daily Rate")
                Spacer()
                TextField("Optional", text: $defaultDailyRate)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("$")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Hourly Rate")
                Spacer()
                TextField("Optional", text: $defaultHourlyRate)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("$/hr")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("On-Call Rate")
                Spacer()
                TextField("Optional", text: $defaultOnCallRate)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("$/hr")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Call-Out Rate")
                Spacer()
                TextField("Optional", text: $defaultCallOutRate)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("$/hr")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Default Rates")
        } footer: {
            Text("These rates will be used as defaults when creating assignments at this location.")
        }
    }

    // MARK: - Default Sessions Section

    private var defaultSessionsSection: some View {
        Section {
            ForEach(defaultSessionTemplates) { template in
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
            .onDelete { indexSet in
                defaultSessionTemplates.remove(atOffsets: indexSet)
            }

            Button {
                showingAddSessionTemplate = true
            } label: {
                Label("Add Session", systemImage: "plus.circle")
            }
        } header: {
            Text("Default Sessions")
        } footer: {
            Text("Default sessions will be pre-filled when recording a work day at this location.")
        }
    }

    private func mmmDescription(for classification: Int) -> String {
        let isEligible = RuralSubsidyService.isEligible(mmmClassification: classification)

        if !isEligible {
            return classification == 1 ? "Metropolitan area - not eligible for WIP subsidy"
                : "Regional centre - not eligible for WIP subsidy"
        }

        let payment = RuralSubsidyService.getAnnualPayment(
            yearLevel: 1,
            mmmClassification: classification,
            registrationStatus: .vocationallyRegistered
        )
        return "Up to \(CurrencyFormatter.format(payment))/year (VR Year 1)"
    }

    private func saveChanges() {
        location.name = name
        location.address = address
        location.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
        location.providerNumber = providerNumber.isEmpty ? nil : providerNumber
        location.notes = notes.isEmpty ? nil : notes
        location.mmmClassification = mmmClassification

        // Update rates
        location.defaultDailyRate = Double(defaultDailyRate)
        location.defaultHourlyRate = Double(defaultHourlyRate)
        location.defaultOnCallRate = Double(defaultOnCallRate)
        location.defaultCallOutRate = Double(defaultCallOutRate)

        // Update session templates
        location.defaultSessionTemplates = defaultSessionTemplates

        location.updatedAt = Date()
        isPresented = false
    }
}

/// Sheet for adding a new session template (used from EditLocationSheet)
private struct EditAddSessionTemplateSheet: View {
    @Binding var isPresented: Bool
    @Binding var templates: [DefaultSessionTemplate]

    @State private var label: String = ""
    @State private var startTime: Date = Calendar.current.date(
        bySettingHour: SessionTemplateDefaults.defaultStartHour,
        minute: 0,
        second: 0,
        of: Date()
    ) ?? Date()
    @State private var endTime: Date = Calendar.current.date(
        bySettingHour: SessionTemplateDefaults.defaultEndHour,
        minute: 0,
        second: 0,
        of: Date()
    ) ?? Date()

    private var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    private var isValidDuration: Bool {
        duration > 0
    }

    /// Formats the duration as a human-readable string (e.g., "4h 30m")
    private var durationText: String {
        guard isValidDuration else { return "Invalid" }
        let hours = Int(duration) / TimeConstants.secondsPerHour
        let minutes = (Int(duration) % TimeConstants.secondsPerHour) / TimeConstants.secondsPerMinute
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    TextField("Label (optional)", text: $label)
                }

                Section("Time") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    LabeledContent("Duration") {
                        Text(durationText)
                            .foregroundStyle(isValidDuration ? Color.primary : Color.red)
                    }
                }
            }
            .navigationTitle("Add Session Template")
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
                    Button("Add") {
                        addTemplate()
                    }
                    .disabled(!isValidDuration)
                }
            }
        }
    }

    private func addTemplate() {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        let template = DefaultSessionTemplate(
            startHour: startComponents.hour ?? SessionTemplateDefaults.defaultStartHour,
            startMinute: startComponents.minute ?? 0,
            endHour: endComponents.hour ?? SessionTemplateDefaults.defaultEndHour,
            endMinute: endComponents.minute ?? 0,
            label: label.isEmpty ? nil : label
        )

        templates.append(template)
        isPresented = false
    }
}

// MARK: - Constants

private enum EditConstants {
    /// Valid range of MMM classifications
    static let classificationRange = 1...7
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
        rateStructure: .dailyRate,
        dailyRate: 450.0,
        startDate: Date(),
        endDate: Date().addingTimeInterval(14 * secondsPerDay),
        status: .active
    )
    container.mainContext.insert(assignment)

    return NavigationStack {
        LocationDetailView(location: location)
    }
    .modelContainer(container)
}
