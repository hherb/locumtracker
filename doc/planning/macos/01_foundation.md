# Phase 1: Foundation

*macOS app target setup and basic navigation*

## Objectives

- Create standalone macOS app target (separate from iOS)
- Configure package dependencies
- Implement basic sidebar navigation
- Verify SwiftData and CloudKit work correctly
- Establish macOS-specific app structure

## Why Separate Target vs. Catalyst

**Decision: Native macOS target (not Catalyst)**

| Approach | Pros | Cons |
|----------|------|------|
| Mac Catalyst | Quick port, same codebase | Limited macOS idioms, iPad UI on Mac |
| Native macOS | Full macOS UX, native controls | More initial setup, some code duplication |

Native macOS allows:
- Proper `NSWindow` management
- Native menu bar integration
- macOS-specific keyboard handling
- Professional desktop appearance

## Prerequisites

- Xcode 15.0+
- macOS 14.0+ (Sonoma) for development and deployment
- Existing packages building successfully

## Implementation Steps

### Step 1: Create macOS App Project

```bash
# Create new directory for macOS app
mkdir -p LocumTrackerMac/LocumTrackerMac
```

Create Xcode project:
1. File → New → Project
2. Select: macOS → App
3. Product Name: `LocumTrackerMac`
4. Team: (your team)
5. Organization Identifier: `com.hherb`
6. Interface: SwiftUI
7. Language: Swift
8. Storage: None (we use our own packages)
9. Location: `/locumtracker/LocumTrackerMac/`

### Step 2: Configure Package Dependencies

Edit `LocumTrackerMac.xcodeproj` to add local packages:

**Package.swift references:**
```
../Packages/LocumTrackerCore
../Packages/LocumTrackerStorage
../Packages/LocumTrackerUI
../Packages/LocumTrackerOCR
```

In Xcode:
1. File → Add Package Dependencies
2. Add Local → Select each package folder
3. Add to target: LocumTrackerMac

### Step 3: App Entry Point

**LocumTrackerMac/App/LocumTrackerMacApp.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerStorage

@main
struct LocumTrackerMacApp: App {
    /// Shared model container with CloudKit sync
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(LocumTrackerSchema.models)

        // CloudKit-enabled configuration
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
            MainWindowView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            AppCommands()
        }

        Settings {
            SettingsWindowView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

### Step 4: Layout Constants

First, define all layout constants to avoid magic numbers throughout the codebase:

**LocumTrackerMac/Constants/LayoutConstants.swift**
```swift
import Foundation

/// Layout constants for consistent UI sizing throughout the macOS app.
///
/// All dimension values are defined here for maintainability and consistency.
/// Use these constants instead of hardcoded numbers in views.
public enum LayoutConstants {
    /// Sidebar panel dimensions.
    public enum Sidebar {
        /// Minimum width for the sidebar panel.
        public static let minWidth: CGFloat = 200
    }

    /// Main window dimensions.
    public enum MainWindow {
        /// Minimum width for the main window.
        public static let minWidth: CGFloat = 900
        /// Minimum height for the main window.
        public static let minHeight: CGFloat = 600
    }

    /// Inspector panel dimensions.
    public enum Inspector {
        /// Minimum width for the inspector panel.
        public static let minWidth: CGFloat = 250
        /// Ideal width for the inspector panel.
        public static let idealWidth: CGFloat = 280
        /// Maximum width for the inspector panel.
        public static let maxWidth: CGFloat = 350
    }

    /// Content area dimensions.
    public enum Content {
        /// Minimum width for the content list area.
        public static let listMinWidth: CGFloat = 300
        /// Minimum width for the detail area.
        public static let detailMinWidth: CGFloat = 400
    }

    /// Settings window dimensions.
    public enum Settings {
        /// Width of the settings window.
        public static let width: CGFloat = 500
        /// Height of the settings window.
        public static let height: CGFloat = 400
    }

    /// Common spacing and padding values.
    public enum Spacing {
        /// Vertical padding for list rows.
        public static let rowVerticalPadding: CGFloat = 4
    }
}
```

### Step 5: Basic Sidebar Navigation

**LocumTrackerMac/Navigation/NavigationState.swift**
```swift
import SwiftUI

/// Tracks the current navigation state across the macOS app.
///
/// This observable class maintains the user's navigation context including
/// the selected sidebar section, the selected item within that section,
/// and inspector visibility state. It serves as the single source of truth
/// for navigation throughout the app.
@Observable
final class NavigationState {
    /// Currently selected sidebar section.
    ///
    /// When `nil`, no section is selected and a placeholder is shown.
    var selectedSection: SidebarSection? = .assignments

    /// Unique identifier of the selected item within the current section.
    ///
    /// When `nil`, no item is selected and the detail area shows a placeholder.
    var selectedItemID: UUID?

    /// Whether the inspector panel is visible.
    ///
    /// Toggle this to show/hide the right-side inspector panel.
    var showInspector: Bool = true
}

/// Sidebar navigation sections available in the macOS app.
///
/// Each section represents a major functional area of the application.
enum SidebarSection: String, CaseIterable, Identifiable {
    case assignments = "Assignments"
    case locations = "Locations"
    case receipts = "Receipts"
    case fpsQuota = "FPS Quota"
    case earnings = "Earnings"
    case reports = "Reports"

    var id: String { rawValue }

    /// SF Symbol name for this section's icon.
    var systemImage: String {
        switch self {
        case .assignments: return "calendar"
        case .locations: return "mappin.and.ellipse"
        case .receipts: return "doc.text"
        case .fpsQuota: return "chart.bar"
        case .earnings: return "dollarsign.circle"
        case .reports: return "chart.pie"
        }
    }
}
```

**LocumTrackerMac/Navigation/SidebarView.swift**
```swift
import SwiftUI

/// Main sidebar navigation for the macOS app.
///
/// Displays grouped navigation sections that allow users to switch
/// between different functional areas of the application.
struct SidebarView: View {
    /// Shared navigation state binding.
    @Bindable var navigationState: NavigationState

    var body: some View {
        List(selection: $navigationState.selectedSection) {
            Section("Work") {
                ForEach([SidebarSection.assignments, .locations]) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
            }

            Section("Tracking") {
                ForEach([SidebarSection.receipts, .fpsQuota, .earnings]) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
            }

            Section("Analysis") {
                Label(SidebarSection.reports.rawValue,
                      systemImage: SidebarSection.reports.systemImage)
                    .tag(SidebarSection.reports)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: LayoutConstants.Sidebar.minWidth)
    }
}
```

### Step 6: Main Window Layout

**LocumTrackerMac/Views/MainWindowView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore

/// Main application window with three-column navigation layout.
///
/// Provides the primary user interface with:
/// - Left: Sidebar for section navigation
/// - Center: Content list for the selected section
/// - Right: Detail view for the selected item
/// - Far right (optional): Inspector panel
struct MainWindowView: View {
    @State private var navigationState = NavigationState()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView {
            SidebarView(navigationState: navigationState)
        } content: {
            ContentAreaView(navigationState: navigationState)
        } detail: {
            DetailAreaView(navigationState: navigationState)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: LayoutConstants.MainWindow.minWidth,
            minHeight: LayoutConstants.MainWindow.minHeight
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarButtons
            }
        }
        .inspector(isPresented: $navigationState.showInspector) {
            InspectorView(navigationState: navigationState)
                .inspectorColumnWidth(
                    min: LayoutConstants.Inspector.minWidth,
                    ideal: LayoutConstants.Inspector.idealWidth,
                    max: LayoutConstants.Inspector.maxWidth
                )
        }
    }

    @ViewBuilder
    private var toolbarButtons: some View {
        Button(action: { /* Add action based on section */ }) {
            Label("Add", systemImage: "plus")
        }
        .help("Add new item")

        Toggle(isOn: $navigationState.showInspector) {
            Label("Inspector", systemImage: "sidebar.right")
        }
        .help("Toggle inspector panel")
    }
}
```

**LocumTrackerMac/Views/ContentAreaView.swift**
```swift
import SwiftUI

/// Content area showing the list view for the currently selected section.
///
/// Renders the appropriate list view based on the navigation state's
/// selected section. Shows a placeholder when no section is selected.
struct ContentAreaView: View {
    /// Shared navigation state binding.
    @Bindable var navigationState: NavigationState

    var body: some View {
        Group {
            switch navigationState.selectedSection {
            case .assignments:
                AssignmentListView(navigationState: navigationState)
            case .locations:
                LocationListView(navigationState: navigationState)
            case .receipts:
                ReceiptListView(navigationState: navigationState)
            case .fpsQuota:
                FPSQuotaView(navigationState: navigationState)
            case .earnings:
                EarningsView(navigationState: navigationState)
            case .reports:
                ReportsView(navigationState: navigationState)
            case .none:
                ContentUnavailableView(
                    "Select a Section",
                    systemImage: "sidebar.left",
                    description: Text("Choose a section from the sidebar")
                )
            }
        }
        .frame(minWidth: LayoutConstants.Content.listMinWidth)
    }
}
```

**LocumTrackerMac/Views/DetailAreaView.swift**
```swift
import SwiftUI

/// Detail view showing the currently selected item.
///
/// Displays the full detail view for the selected item based on
/// the current section. Shows a placeholder when no item is selected.
struct DetailAreaView: View {
    /// Shared navigation state binding.
    @Bindable var navigationState: NavigationState

    var body: some View {
        Group {
            if navigationState.selectedItemID != nil {
                switch navigationState.selectedSection {
                case .assignments:
                    AssignmentDetailView(navigationState: navigationState)
                case .locations:
                    LocationDetailView(navigationState: navigationState)
                case .receipts:
                    ReceiptDetailView(navigationState: navigationState)
                default:
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
        .frame(minWidth: LayoutConstants.Content.detailMinWidth)
    }

    private var placeholderView: some View {
        ContentUnavailableView(
            "No Selection",
            systemImage: "doc.text.magnifyingglass",
            description: Text("Select an item to view details")
        )
    }
}
```

### Step 7: Placeholder Views

Create placeholder implementations for each section view that will be fully implemented in Phase 2:

**LocumTrackerMac/Views/Assignments/AssignmentListView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore

/// List view displaying all assignments in the sidebar content area.
///
/// This is a placeholder implementation that will be expanded in Phase 2
/// with table-based display, sorting, and filtering.
struct AssignmentListView: View {
    /// Shared navigation state binding.
    @Bindable var navigationState: NavigationState

    /// All assignments, sorted by start date descending (most recent first).
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]

    var body: some View {
        List(assignments, selection: $navigationState.selectedItemID) { assignment in
            AssignmentRowView(assignment: assignment)
                .tag(assignment.id)
        }
        .navigationTitle("Assignments")
    }
}

/// Row view for displaying a single assignment in a list.
///
/// Shows the assignment name and start date in a compact format.
struct AssignmentRowView: View {
    /// The assignment to display.
    let assignment: Assignment

    var body: some View {
        VStack(alignment: .leading) {
            Text(assignment.name ?? "Unnamed Assignment")
                .font(.headline)
            Text(assignment.startDate, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, LayoutConstants.Spacing.rowVerticalPadding)
    }
}
```

Create similar placeholder files for:
- `LocationListView.swift`
- `ReceiptListView.swift`
- `FPSQuotaView.swift`
- `EarningsView.swift`
- `ReportsView.swift`
- `AssignmentDetailView.swift`
- `LocationDetailView.swift`
- `ReceiptDetailView.swift`
- `InspectorView.swift`

### Step 8: Basic Commands

**LocumTrackerMac/App/AppCommands.swift**
```swift
import SwiftUI

/// Custom menu commands for the macOS app.
///
/// Provides menu bar integration for common actions including
/// creating new items and toggling the inspector panel.
struct AppCommands: Commands {
    /// Focused binding to access the navigation state from menu commands.
    @FocusedBinding(\.navigationState) var navigationState: NavigationState?

    var body: some Commands {
        // Replace default New command
        CommandGroup(replacing: .newItem) {
            Menu("New") {
                Button("New Assignment") {
                    NotificationCenter.default.post(
                        name: .newAssignment,
                        object: nil
                    )
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Location") {
                    NotificationCenter.default.post(
                        name: .newLocation,
                        object: nil
                    )
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("New Receipt") {
                    NotificationCenter.default.post(
                        name: .newReceipt,
                        object: nil
                    )
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }
        }

        // View menu additions
        CommandGroup(after: .sidebar) {
            Toggle("Show Inspector", isOn: Binding(
                get: { navigationState?.showInspector ?? true },
                set: { navigationState?.showInspector = $0 }
            ))
            .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}

/// Notification names for app-wide actions.
extension Notification.Name {
    /// Posted when user requests a new assignment.
    static let newAssignment = Notification.Name("newAssignment")
    /// Posted when user requests a new location.
    static let newLocation = Notification.Name("newLocation")
    /// Posted when user requests a new receipt.
    static let newReceipt = Notification.Name("newReceipt")
}

/// Focus key for accessing navigation state from menu commands.
struct NavigationStateFocusKey: FocusedValueKey {
    typealias Value = Binding<NavigationState>
}

extension FocusedValues {
    /// Binding to the current window's navigation state.
    var navigationState: Binding<NavigationState>? {
        get { self[NavigationStateFocusKey.self] }
        set { self[NavigationStateFocusKey.self] = newValue }
    }
}
```

### Step 9: Settings Window

**LocumTrackerMac/Settings/SettingsWindowView.swift**
```swift
import SwiftUI

/// Settings window for macOS app preferences.
///
/// Provides tabbed interface for configuring general settings,
/// user profile, and sync options.
struct SettingsWindowView: View {
    /// Available settings tabs.
    private enum Tabs: Hashable {
        case general
        case profile
        case sync
    }

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)

            ProfileSettingsTab()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(Tabs.profile)

            SyncSettingsTab()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(Tabs.sync)
        }
        .frame(
            width: LayoutConstants.Settings.width,
            height: LayoutConstants.Settings.height
        )
    }
}

/// General application settings tab.
struct GeneralSettingsTab: View {
    /// Default MMM classification for new locations (1-7).
    @AppStorage("defaultMMMClassification") private var defaultMMM = 3

    var body: some View {
        Form {
            Picker("Default MMM Classification", selection: $defaultMMM) {
                ForEach(1...7, id: \.self) { mmm in
                    Text("MMM \(mmm)").tag(mmm)
                }
            }
        }
        .padding()
    }
}

/// User profile settings tab (placeholder).
struct ProfileSettingsTab: View {
    var body: some View {
        Text("Profile settings - connects to LocumProfile")
            .padding()
    }
}

/// CloudKit sync settings tab (placeholder).
struct SyncSettingsTab: View {
    var body: some View {
        Text("CloudKit sync status and settings")
            .padding()
    }
}
```

### Step 10: Configure Entitlements

**LocumTrackerMac/LocumTrackerMac.entitlements**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.hherb.locumtracker</string>
    </array>
</dict>
</plist>
```

## Testing Phase 1

### Build Verification
```bash
cd LocumTrackerMac
xcodebuild -scheme LocumTrackerMac -destination 'platform=macOS' build
```

### Manual Testing Checklist

- [ ] App launches without crash
- [ ] Sidebar displays all sections
- [ ] Clicking sections changes content area
- [ ] Three-column layout resizes properly
- [ ] Inspector panel toggles visibility
- [ ] Settings window opens (Cmd+,)
- [ ] Data syncs from iOS app (if CloudKit configured)
- [ ] New menu items appear

### Known Limitations (Fixed in Phase 2)

- List views show placeholder content
- Detail views are stubs
- Inspector shows placeholder
- No actual data editing yet

## Files Created

```
LocumTrackerMac/
├── LocumTrackerMac.xcodeproj
└── LocumTrackerMac/
    ├── App/
    │   ├── LocumTrackerMacApp.swift
    │   └── AppCommands.swift
    ├── Constants/
    │   └── LayoutConstants.swift
    ├── Navigation/
    │   ├── NavigationState.swift
    │   └── SidebarView.swift
    ├── Views/
    │   ├── MainWindowView.swift
    │   ├── ContentAreaView.swift
    │   ├── DetailAreaView.swift
    │   ├── Assignments/
    │   │   ├── AssignmentListView.swift
    │   │   └── AssignmentDetailView.swift
    │   ├── Locations/
    │   │   ├── LocationListView.swift
    │   │   └── LocationDetailView.swift
    │   ├── Receipts/
    │   │   ├── ReceiptListView.swift
    │   │   └── ReceiptDetailView.swift
    │   ├── FPSQuota/
    │   │   └── FPSQuotaView.swift
    │   ├── Earnings/
    │   │   └── EarningsView.swift
    │   └── Reports/
    │       └── ReportsView.swift
    ├── Inspectors/
    │   └── InspectorView.swift
    ├── Settings/
    │   └── SettingsWindowView.swift
    ├── Resources/
    │   └── Assets.xcassets
    └── LocumTrackerMac.entitlements
```

## Estimated Scope

- **New files**: ~20
- **Lines of code**: ~800-1000
- **Dependencies**: 4 existing packages
- **Build time**: Should be quick (leveraging existing packages)

## Next Phase

Proceed to [Phase 2: Core Views](02_core_views.md) to implement full view functionality.
