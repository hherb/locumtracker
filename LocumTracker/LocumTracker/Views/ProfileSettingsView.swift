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

/// View for editing user profile and settings
///
/// Allows users to configure their professional details including:
/// - Personal information (title, name, email)
/// - Address for invoicing
/// - Business structure and tax details (ABN with validation, GST registration)
/// - Vocational status for WIP FPS calculations
/// - Default rate configuration
struct ProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [LocumProfile]

    // MARK: - Form State

    // Personal Information
    @State private var title: ProfessionalTitle = .dr
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""

    // Address
    @State private var streetAddress: String = ""
    @State private var suburb: String = ""
    @State private var state: String = ""
    @State private var postcode: String = ""

    // Business & Tax
    @State private var businessStructure: BusinessStructure = .individual
    @State private var abn: String = ""
    @State private var gstRegistered: Bool = false

    // Professional Status
    @State private var isVocational: Bool = true
    @State private var providerNumber: String = ""
    @State private var specialty: String = ""

    // Default rates
    @State private var defaultDailyRate: Double = 0
    @State private var defaultHourlyRate: Double = 0
    @State private var defaultOnCallRate: Double = 0
    @State private var defaultCallOutRate: Double = 0

    // Validation state
    @State private var abnValidationState: ABNValidationState = .empty
    @State private var showingSaveConfirmation: Bool = false

    /// The existing profile if editing
    private var existingProfile: LocumProfile? {
        profiles.first
    }

    /// Whether this is creating a new profile
    private var isNewProfile: Bool {
        existingProfile == nil
    }

    // MARK: - Body

    var body: some View {
        Form {
            personalInfoSection
            addressSection
            businessTaxSection
            professionalStatusSection
            defaultRatesSection
        }
        .navigationTitle(isNewProfile ? "Set Up Profile" : "Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            loadExistingProfile()
        }
        .alert("Profile Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) {
                if !isNewProfile {
                    dismiss()
                }
            }
        } message: {
            Text("Your profile has been saved successfully.")
        }
    }

    // MARK: - View Components

    private var personalInfoSection: some View {
        Section("Personal Information") {
            Picker("Title", selection: $title) {
                ForEach(ProfessionalTitle.allCases, id: \.self) { titleOption in
                    Text(titleOption.description).tag(titleOption)
                }
            }
            .accessibilityIdentifier("titlePicker")

            TextField("First Name", text: $firstName)
                .textContentType(.givenName)
                .accessibilityIdentifier("firstNameField")
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif

            TextField("Last Name", text: $lastName)
                .textContentType(.familyName)
                .accessibilityIdentifier("lastNameField")
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .accessibilityIdentifier("emailField")
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif
        }
    }

    private var addressSection: some View {
        Section {
            TextField("Street Address", text: $streetAddress)
                .textContentType(.streetAddressLine1)
                .accessibilityIdentifier("streetAddressField")
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif

            TextField("Suburb", text: $suburb)
                .textContentType(.addressCity)
                .accessibilityIdentifier("suburbField")
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif

            HStack {
                Picker("State", selection: $state) {
                    Text("Select").tag("")
                    ForEach(AustralianStates.allCases, id: \.self) { stateOption in
                        Text(stateOption.rawValue).tag(stateOption.rawValue)
                    }
                }
                .accessibilityIdentifier("statePicker")

                TextField("Postcode", text: $postcode)
                    .textContentType(.postalCode)
                    .accessibilityIdentifier("postcodeField")
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .frame(width: PostcodeFieldConstants.width)
            }
        } header: {
            Text("Address")
        } footer: {
            Text("Used for invoicing")
        }
    }

    private var businessTaxSection: some View {
        Section {
            Picker("Business Structure", selection: $businessStructure) {
                ForEach(BusinessStructure.allCases, id: \.self) { structure in
                    Text(structure.description).tag(structure)
                }
            }
            .accessibilityIdentifier("businessStructurePicker")

            // ABN field with validation
            VStack(alignment: .leading, spacing: FormConstants.fieldSpacing) {
                TextField("ABN (optional)", text: $abn)
                    .accessibilityIdentifier("abnField")
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .onChange(of: abn) { _, newValue in
                        validateABN(newValue)
                    }

                // Validation feedback
                abnValidationFeedback
            }

            Toggle("GST Registered", isOn: $gstRegistered)
                .accessibilityIdentifier("gstToggle")

            if gstRegistered {
                Text("GST (10%) will be added to invoices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Business & Tax")
        } footer: {
            if !abn.isEmpty && abnValidationState == .valid {
                Text("ABN: \(TaxService.formatABN(abn))")
            }
        }
    }

    @ViewBuilder
    private var abnValidationFeedback: some View {
        switch abnValidationState {
        case .empty:
            EmptyView()
        case .tooShort:
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("ABN must be 11 digits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("abnValidation_tooShort")
        case .invalid:
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text("Invalid ABN - please check the number")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .accessibilityIdentifier("abnValidation_invalid")
        case .valid:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("Valid ABN")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .accessibilityIdentifier("abnValidation_valid")
        }
    }

    private var professionalStatusSection: some View {
        Section {
            Toggle("Vocationally Registered (VR)", isOn: $isVocational)
                .accessibilityIdentifier("vocationalToggle")

            if !isVocational {
                Text("Non-VR receives 80% of WIP FPS payment rates")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Provider Number", text: $providerNumber)
                .accessibilityIdentifier("providerNumberField")

            TextField("Specialty", text: $specialty)
                .accessibilityIdentifier("specialtyField")
        } header: {
            Text("Professional Status")
        } footer: {
            Text("Vocational registration affects WIP Doctor Stream subsidy calculations")
        }
    }

    private var defaultRatesSection: some View {
        Section {
            HStack {
                Text("Daily Rate")
                Spacer()
                TextField("$0", value: $defaultDailyRate, format: .currency(code: "AUD"))
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("defaultDailyRateField")
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .frame(width: RateFieldConstants.width)
            }

            HStack {
                Text("Hourly Rate")
                Spacer()
                TextField("$0", value: $defaultHourlyRate, format: .currency(code: "AUD"))
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("defaultHourlyRateField")
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .frame(width: RateFieldConstants.width)
            }

            HStack {
                Text("On-Call Rate")
                Spacer()
                TextField("$0", value: $defaultOnCallRate, format: .currency(code: "AUD"))
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("defaultOnCallRateField")
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .frame(width: RateFieldConstants.width)
            }

            HStack {
                Text("Call-Out Rate")
                Spacer()
                TextField("$0", value: $defaultCallOutRate, format: .currency(code: "AUD"))
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("defaultCallOutRateField")
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .frame(width: RateFieldConstants.width)
            }
        } header: {
            Text("Default Rates")
        } footer: {
            Text("These rates will be suggested when creating new assignments")
        }
    }

    // MARK: - Validation

    /// Whether the form can be saved
    private var canSave: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty &&
        (abn.isEmpty || abnValidationState == .valid)
    }

    /// Validates the ABN input
    private func validateABN(_ input: String) {
        let cleanABN = input.filter { $0.isNumber }

        if cleanABN.isEmpty {
            abnValidationState = .empty
        } else if cleanABN.count < 11 {
            abnValidationState = .tooShort
        } else if cleanABN.count == 11 {
            if TaxService.validateABN(cleanABN) {
                abnValidationState = .valid
            } else {
                abnValidationState = .invalid
            }
        } else {
            // More than 11 digits - trim to 11
            abn = String(cleanABN.prefix(11))
        }
    }

    // MARK: - Data Operations

    /// Loads existing profile data into form fields
    private func loadExistingProfile() {
        guard let profile = existingProfile else { return }

        // Personal Information
        title = profile.title
        firstName = profile.firstName
        lastName = profile.lastName
        email = profile.email

        // Address
        streetAddress = profile.streetAddress
        suburb = profile.suburb
        state = profile.state
        postcode = profile.postcode

        // Business & Tax
        businessStructure = profile.businessStructure
        abn = profile.abn ?? ""
        gstRegistered = profile.gstRegistered

        // Professional Status
        isVocational = profile.isVocational
        providerNumber = profile.providerNumber ?? ""
        specialty = profile.specialty ?? ""

        // Default Rates
        defaultDailyRate = profile.defaultDailyRate
        defaultHourlyRate = profile.defaultHourlyRate
        defaultOnCallRate = profile.defaultOnCallRate ?? 0
        defaultCallOutRate = profile.defaultCallOutRate ?? 0

        // Validate ABN if present
        if !abn.isEmpty {
            validateABN(abn)
        }
    }

    /// Saves the profile to the database
    private func saveProfile() {
        let cleanABN = abn.filter { $0.isNumber }

        if let profile = existingProfile {
            // Update existing profile
            profile.title = title
            profile.firstName = firstName
            profile.lastName = lastName
            profile.email = email
            profile.streetAddress = streetAddress
            profile.suburb = suburb
            profile.state = state
            profile.postcode = postcode
            profile.businessStructure = businessStructure
            profile.abn = cleanABN.isEmpty ? nil : cleanABN
            profile.gstRegistered = gstRegistered
            profile.isVocational = isVocational
            profile.providerNumber = providerNumber.isEmpty ? nil : providerNumber
            profile.specialty = specialty.isEmpty ? nil : specialty
            profile.defaultDailyRate = defaultDailyRate
            profile.defaultHourlyRate = defaultHourlyRate
            profile.defaultOnCallRate = defaultOnCallRate > 0 ? defaultOnCallRate : nil
            profile.defaultCallOutRate = defaultCallOutRate > 0 ? defaultCallOutRate : nil
            profile.updatedAt = Date()
        } else {
            // Create new profile
            let newProfile = LocumProfile(
                title: title,
                firstName: firstName,
                lastName: lastName,
                email: email,
                streetAddress: streetAddress,
                suburb: suburb,
                state: state,
                postcode: postcode,
                businessStructure: businessStructure,
                abn: cleanABN.isEmpty ? nil : cleanABN,
                gstRegistered: gstRegistered,
                isVocational: isVocational,
                defaultDailyRate: defaultDailyRate,
                defaultHourlyRate: defaultHourlyRate,
                defaultOnCallRate: defaultOnCallRate > 0 ? defaultOnCallRate : nil,
                defaultCallOutRate: defaultCallOutRate > 0 ? defaultCallOutRate : nil,
                providerNumber: providerNumber.isEmpty ? nil : providerNumber,
                specialty: specialty.isEmpty ? nil : specialty
            )
            modelContext.insert(newProfile)
        }

        showingSaveConfirmation = true
    }
}

// MARK: - Supporting Types

/// ABN validation states for UI feedback
private enum ABNValidationState {
    case empty
    case tooShort
    case invalid
    case valid
}

// MARK: - Constants

private enum FormConstants {
    static let fieldSpacing: CGFloat = 4
}

private enum RateFieldConstants {
    static let width: CGFloat = 120
}

private enum PostcodeFieldConstants {
    static let width: CGFloat = 100
}

/// Australian states and territories for address picker
private enum AustralianStates: String, CaseIterable {
    case nsw = "NSW"
    case vic = "VIC"
    case qld = "QLD"
    case wa = "WA"
    case sa = "SA"
    case tas = "TAS"
    case act = "ACT"
    case nt = "NT"
}

// MARK: - Preview

#Preview("New Profile") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([LocumProfile.self])
    let container = try! ModelContainer(for: schema, configurations: config)

    return NavigationStack {
        ProfileSettingsView()
    }
    .modelContainer(container)
}

#Preview("Existing Profile") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([LocumProfile.self])
    let container = try! ModelContainer(for: schema, configurations: config)

    let profile = LocumProfile(
        title: .dr,
        firstName: "Jane",
        lastName: "Smith",
        email: "jane.smith@example.com",
        streetAddress: "123 Medical Centre Drive",
        suburb: "Sydney",
        state: "NSW",
        postcode: "2000",
        businessStructure: .soleTrader,
        abn: "51824753556",
        gstRegistered: true,
        isVocational: true,
        defaultDailyRate: 2500,
        defaultHourlyRate: 180,
        defaultOnCallRate: 45,
        defaultCallOutRate: 90,
        providerNumber: "1234567A",
        specialty: "General Practice"
    )
    container.mainContext.insert(profile)

    return NavigationStack {
        ProfileSettingsView()
    }
    .modelContainer(container)
}
