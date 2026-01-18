import SwiftUI
import SwiftData
import LocumTrackerCore

/// Sheet view for adding a new location to the system
struct AddLocationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var address = ""
    @State private var mmmClassification = MMMDefaults.defaultClassification

    var body: some View {
        NavigationStack {
            Form {
                Section("Location Details") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
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
        }
    }

    /// Returns a human-readable description of the MMM classification
    /// - Parameter classification: The MMM level (1-7)
    /// - Returns: Description including eligibility and subsidy rate
    private func mmmDescription(for classification: Int) -> String {
        let baseRate = RuralSubsidyService.getBaseRate(for: classification)
        let isEligible = RuralSubsidyService.isEligible(mmmClassification: classification)

        switch classification {
        case 1:
            return "Metropolitan area - not eligible for rural subsidy"
        case 2:
            return "Regional centre - not eligible for rural subsidy"
        case 3:
            return "Large rural town - eligible for rural subsidy"
        case 4, 5, 6, 7:
            let areaName = areaDescription(for: classification)
            return "\(areaName) - $\(Int(baseRate))/hour subsidy"
        default:
            return isEligible ? "Eligible for rural subsidy" : "Not eligible for rural subsidy"
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
            mmmClassification: mmmClassification
        )
        modelContext.insert(location)
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
