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
import LocumTrackerStorage

/// Main entry point for the LocumTracker application
///
/// Configures SwiftData persistence with CloudKit sync and provides
/// the main window scene. On macOS, also provides a Settings scene.
@main
struct LocumTrackerApp: App {
    /// Tracks scene phase for processing pending attachments
    @Environment(\.scenePhase) private var scenePhase

    /// Shared model container - tries CloudKit first, falls back to local storage
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(LocumTrackerSchema.models)

        // Try CloudKit-enabled configuration first
        let cloudKitConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(LocumTrackerStorage.cloudKitContainerID)
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudKitConfig])
        } catch {
            print("CloudKit ModelContainer failed: \(error)")
            print("Falling back to local-only storage...")

            // Fall back to local-only storage
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            MainTabView()
                .onAppear {
                    updateAssignmentsCache()
                }
            #else
            ContentView()
            #endif
        }
        .modelContainer(sharedModelContainer)
        #if os(iOS)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                processPendingAttachments()
                updateAssignmentsCache()
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }

    // MARK: - Share Extension Support

    #if os(iOS)
    /// Process any pending attachments from the Share Extension
    @MainActor
    private func processPendingAttachments() {
        let context = sharedModelContainer.mainContext
        let processor = PendingAttachmentProcessor(modelContext: context)
        let count = processor.processAllPending()
        if count > 0 {
            print("Processed \(count) pending attachment(s) from Share Extension")
        }
    }

    /// Update the cached assignment list for the Share Extension picker
    @MainActor
    private func updateAssignmentsCache() {
        let context = sharedModelContainer.mainContext

        // Fetch all assignments
        let assignmentDescriptor = FetchDescriptor<Assignment>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        guard let assignments = try? context.fetch(assignmentDescriptor) else { return }

        // Fetch all locations for display names
        let locationDescriptor = FetchDescriptor<Location>()
        let locations = (try? context.fetch(locationDescriptor)) ?? []
        let locationMap = Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0.name) })

        // Convert to cached format
        let cached = assignments.map { assignment in
            CachedAssignment(
                id: assignment.id,
                name: assignment.name,
                locationName: locationMap[assignment.locationId] ?? "Unknown Location",
                startDate: assignment.startDate,
                endDate: assignment.endDate,
                status: assignment.status.rawValue
            )
        }

        do {
            try SharedDataService.writeAssignmentsCache(cached)
        } catch {
            print("Failed to update assignments cache: \(error)")
        }
    }
    #endif
}

// MARK: - macOS Settings

#if os(macOS)
/// Settings window for macOS
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: SettingsConstants.windowWidth, height: SettingsConstants.windowHeight)
    }
}

/// General settings tab content
struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("LocumTracker Settings")
                .font(.headline)
            Text("Configure your preferences here.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private enum SettingsConstants {
    static let windowWidth: CGFloat = 400
    static let windowHeight: CGFloat = 300
}
#endif
