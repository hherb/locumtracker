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
            ContentView()
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
