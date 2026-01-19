import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

/// View for editing user profile and settings
///
/// Allows users to configure their professional details including:
/// - Personal information (name, email)
/// - Tax details (ABN with validation, GST registration)
/// - Vocational status for WIP FPS calculations
/// - Default rate configuration
struct ProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [LocumProfile]

    // MARK: - Form State

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var abn: String = ""
    @State private var gstRegistered: Bool = false
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
            taxDetailsSection
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

    private var taxDetailsSection: some View {
        Section {
            // ABN field with validation
            VStack(alignment: .leading, spacing: FormConstants.fieldSpacing) {
                TextField("ABN", text: $abn)
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
            Text("Tax Details")
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

        firstName = profile.firstName
        lastName = profile.lastName
        email = profile.email
        abn = profile.abn ?? ""
        gstRegistered = profile.gstRegistered
        isVocational = profile.isVocational
        providerNumber = profile.providerNumber ?? ""
        specialty = profile.specialty ?? ""
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
            profile.firstName = firstName
            profile.lastName = lastName
            profile.email = email
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
                firstName: firstName,
                lastName: lastName,
                email: email,
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
        firstName: "Jane",
        lastName: "Smith",
        email: "jane.smith@example.com",
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
