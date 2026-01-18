import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

/// View displaying a list of all locations with filtering by MMM classification
struct LocationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Location.name) private var locations: [Location]

    @State private var showingAddLocation = false
    @State private var searchText = ""
    @State private var filterClassification: Int? = nil

    /// Locations filtered by search text and MMM classification
    private var filteredLocations: [Location] {
        locations.filter { location in
            let matchesSearch = searchText.isEmpty ||
                location.name.localizedCaseInsensitiveContains(searchText) ||
                location.address.localizedCaseInsensitiveContains(searchText)

            let matchesFilter = filterClassification == nil ||
                location.mmmClassification == filterClassification

            return matchesSearch && matchesFilter
        }
    }

    /// Locations grouped by subsidy eligibility
    private var groupedLocations: [(title: String, locations: [Location])] {
        let eligible = filteredLocations.filter { $0.isRuralSubsidyEligible }
        let notEligible = filteredLocations.filter { !$0.isRuralSubsidyEligible }

        var groups: [(String, [Location])] = []
        if !eligible.isEmpty {
            groups.append(("Subsidy Eligible (MMM3-7)", eligible))
        }
        if !notEligible.isEmpty {
            groups.append(("Metropolitan/Regional (MMM1-2)", notEligible))
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredLocations.isEmpty {
                    emptyStateView
                } else {
                    ForEach(groupedLocations, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.locations) { location in
                                NavigationLink(value: location) {
                                    LocationRowView(location: location)
                                }
                            }
                            .onDelete { offsets in
                                deleteLocations(at: offsets, from: group.locations)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Locations")
            .navigationDestination(for: Location.self) { location in
                LocationDetailView(location: location)
            }
            .searchable(text: $searchText, prompt: "Search locations")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddLocation = true
                    } label: {
                        Label("Add Location", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    filterMenu
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationSheet(isPresented: $showingAddLocation)
            }
        }
    }

    // MARK: - View Components

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Locations", systemImage: "mappin.slash")
        } description: {
            if !searchText.isEmpty || filterClassification != nil {
                Text("No locations match your search criteria.")
            } else {
                Text("Add your first location to get started.")
            }
        } actions: {
            if searchText.isEmpty && filterClassification == nil {
                Button("Add Location") {
                    showingAddLocation = true
                }
            } else {
                Button("Clear Filters") {
                    searchText = ""
                    filterClassification = nil
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Button {
                filterClassification = nil
            } label: {
                Label("All Classifications", systemImage: filterClassification == nil ? "checkmark" : "")
            }

            Divider()

            ForEach(FilterConstants.classificationRange, id: \.self) { level in
                Button {
                    filterClassification = level
                } label: {
                    Label("MMM\(level)", systemImage: filterClassification == level ? "checkmark" : "")
                }
            }
        } label: {
            Label("Filter", systemImage: filterClassification != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    // MARK: - Actions

    private func deleteLocations(at offsets: IndexSet, from groupLocations: [Location]) {
        for index in offsets {
            modelContext.delete(groupLocations[index])
        }
    }
}

// MARK: - Location Row View

/// Row view displaying a single location in the list
struct LocationRowView: View {
    let location: Location

    var body: some View {
        VStack(alignment: .leading, spacing: RowConstants.verticalSpacing) {
            HStack {
                Text(location.name)
                    .font(.headline)
                Spacer()
                MMMBadge(classification: location.mmmClassification)
            }

            Text(location.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if location.isRuralSubsidyEligible {
                let rate = RuralSubsidyService.getBaseRate(for: location.mmmClassification)
                Text("$\(Int(rate))/hr subsidy")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, RowConstants.rowVerticalPadding)
    }
}

// MARK: - Constants

private enum RowConstants {
    static let verticalSpacing: CGFloat = 4
    static let rowVerticalPadding: CGFloat = 4
}

private enum FilterConstants {
    static let classificationRange = 1...7
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Location.self, configurations: config)

    let locations = [
        Location(name: "Royal Darwin Hospital", address: "Rocklands Dr, Tiwi NT 0810", mmmClassification: 5),
        Location(name: "Cooktown Hospital", address: "Hope St, Cooktown QLD 4895", mmmClassification: 6),
        Location(name: "Royal Brisbane Hospital", address: "Butterfield St, Herston QLD 4006", mmmClassification: 1),
        Location(name: "Cairns Hospital", address: "The Esplanade, Cairns QLD 4870", mmmClassification: 2)
    ]
    locations.forEach { container.mainContext.insert($0) }

    return LocationListView()
        .modelContainer(container)
}
