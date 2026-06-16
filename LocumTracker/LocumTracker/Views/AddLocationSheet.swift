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

/// Sheet view for adding a new location to the system
struct AddLocationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var address = ""
    @State private var phoneNumber = ""
    @State private var providerNumber = ""
    @State private var notes = ""
    @State private var mmmClassification = MMMDefaults.defaultClassification

    // Default rates
    @State private var defaultDailyRate: String = ""
    @State private var defaultHourlyRate: String = ""
    @State private var defaultOnCallRate: String = ""
    @State private var defaultCallOutRate: String = ""

    // Default session templates
    @State private var defaultSessionTemplates: [DefaultSessionTemplate] = []
    @State private var showingAddSessionTemplate = false

    var body: some View {
        // TODO: Using NavigationView instead of NavigationStack as a workaround for
        // a SwiftUI bug where TextField state is lost when switching between fields
        // in sheets presented from NavigationStack. Remove when Apple fixes this issue.
        NavigationView {
            Form {
                Section("Location Details") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Phone Number", text: $phoneNumber)
#if os(iOS)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
#endif
                }

                Section("Medicare") {
                    TextField("Provider Number", text: $providerNumber)
                        .textInputAutocapitalization(.characters)
                }

                Section("MMM Classification") {
                    Picker("MMM Level", selection: $mmmClassification) {
                        ForEach(MMMDefaults.classificationRange, id: \.self) { level in
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
            .navigationTitle("Add Location")
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
                        saveLocation()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddSessionTemplate) {
                AddSessionTemplateSheet(
                    isPresented: $showingAddSessionTemplate,
                    templates: $defaultSessionTemplates
                )
            }
        }
#if os(iOS)
        .navigationViewStyle(.stack)
#endif
    }

    // MARK: - Default Rates Section

    private var defaultRatesSection: some View {
        Section {
            HStack {
                Text("Daily Rate")
                Spacer()
                TextField("Optional", text: $defaultDailyRate)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("$")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Hourly Rate")
                Spacer()
                TextField("Optional", text: $defaultHourlyRate)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("$/hr")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("On-Call Rate")
                Spacer()
                TextField("Optional", text: $defaultOnCallRate)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("$/hr")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Call-Out Rate")
                Spacer()
                TextField("Optional", text: $defaultCallOutRate)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
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

    /// Returns a human-readable description of the MMM classification
    /// - Parameter classification: The MMM level (1-7)
    /// - Returns: Description including eligibility and WIP FPS payment info
    private func mmmDescription(for classification: Int) -> String {
        let isEligible = RuralSubsidyService.isEligible(mmmClassification: classification)

        switch classification {
        case 1:
            return "Metropolitan area - not eligible for WIP subsidy"
        case 2:
            return "Regional centre - not eligible for WIP subsidy"
        case 3, 4, 5, 6, 7:
            let areaName = areaDescription(for: classification)
            let annualPayment = RuralSubsidyService.getAnnualPayment(
                yearLevel: 1,
                mmmClassification: classification,
                registrationStatus: .vocationallyRegistered
            )
            let formattedPayment = NumberFormatter.localizedString(from: NSNumber(value: annualPayment), number: .currency)
            return "\(areaName) - \(formattedPayment)/year (Year 1 VR)"
        default:
            return isEligible ? "Eligible for WIP subsidy" : "Not eligible for WIP subsidy"
        }
    }

    /// Returns the area type description for an MMM classification
    /// - Parameter classification: The MMM level (4-7)
    /// - Returns: Human-readable area description
    private func areaDescription(for classification: Int) -> String {
        switch classification {
        case 4: return "Medium rural town"
        case 5: return "Small rural town"
        case 6: return "Remote community"
        case 7: return "Very remote community"
        default: return "Rural area"
        }
    }

    private func saveLocation() {
        let location = Location(
            name: name,
            address: address,
            mmmClassification: mmmClassification,
            providerNumber: providerNumber.isEmpty ? nil : providerNumber,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            notes: notes.isEmpty ? nil : notes,
            defaultDailyRate: Double(defaultDailyRate),
            defaultHourlyRate: Double(defaultHourlyRate),
            defaultOnCallRate: Double(defaultOnCallRate),
            defaultCallOutRate: Double(defaultCallOutRate),
            defaultSessionTemplates: defaultSessionTemplates
        )
        modelContext.insert(location)
        isPresented = false
    }
}

// MARK: - Add Session Template Sheet

/// Sheet for adding a new session template to a location
struct AddSessionTemplateSheet: View {
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
        NavigationView {
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
#if os(iOS)
        .navigationViewStyle(.stack)
#endif
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

/// Default values for MMM classification UI
private enum MMMDefaults {
    /// Valid range of MMM classifications
    static let classificationRange = 1...7
    /// Default classification for new locations
    static let defaultClassification = 4
}

#Preview {
    AddLocationSheet(isPresented: .constant(true))
        .modelContainer(for: Location.self, inMemory: true)
}

