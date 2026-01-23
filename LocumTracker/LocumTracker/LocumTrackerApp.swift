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
            #else
            ContentView()
            #endif
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
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
