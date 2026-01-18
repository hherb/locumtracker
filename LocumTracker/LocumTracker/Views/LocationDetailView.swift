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
            HStack {
                Text("MMM Classification")
                Spacer()
                MMMBadge(classification: location.mmmClassification)
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
    @State private var mmmClassification: Int

    init(isPresented: Binding<Bool>, location: Location) {
        self._isPresented = isPresented
        self.location = location
        _name = State(initialValue: location.name)
        _address = State(initialValue: location.address)
        _mmmClassification = State(initialValue: location.mmmClassification)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location Details") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
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
        location.mmmClassification = mmmClassification
        location.updatedAt = Date()
        isPresented = false
    }
}

// MARK: - Constants

private enum EditConstants {
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
