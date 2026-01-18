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
    /// Shared model container with CloudKit sync enabled
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(LocumTrackerSchema.models)

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(LocumTrackerStorage.cloudKitContainerID)
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
