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

### Step 4: Basic Sidebar Navigation

**LocumTrackerMac/Navigation/NavigationState.swift**
```swift
import SwiftUI

/// Tracks the current navigation state across the app
@Observable
final class NavigationState {
    /// Currently selected sidebar section
    var selectedSection: SidebarSection? = .assignments

    /// Selected item within the current section
    var selectedItemID: UUID?

    /// Whether the inspector panel is visible
    var showInspector: Bool = true
}

/// Sidebar navigation sections
enum SidebarSection: String, CaseIterable, Identifiable {
    case assignments = "Assignments"
    case locations = "Locations"
    case receipts = "Receipts"
    case fpsQuota = "FPS Quota"
    case earnings = "Earnings"
    case reports = "Reports"

    var id: String { rawValue }

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

/// Main sidebar navigation for macOS
struct SidebarView: View {
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
        .frame(minWidth: 200)
    }
}
```

### Step 5: Main Window Layout

**LocumTrackerMac/Views/MainWindowView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore

/// Main window with three-column layout
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
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarButtons
            }
        }
        .inspector(isPresented: $navigationState.showInspector) {
            InspectorView(navigationState: navigationState)
                .inspectorColumnWidth(min: 250, ideal: 280, max: 350)
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

/// Content area showing list for selected section
struct ContentAreaView: View {
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
        .frame(minWidth: 300)
    }
}
```

**LocumTrackerMac/Views/DetailAreaView.swift**
```swift
import SwiftUI

/// Detail view showing selected item
struct DetailAreaView: View {
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
        .frame(minWidth: 400)
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

### Step 6: Placeholder Views

Create placeholder implementations for each section view that will be fully implemented in Phase 2:

**LocumTrackerMac/Views/Assignments/AssignmentListView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore

struct AssignmentListView: View {
    @Bindable var navigationState: NavigationState
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]

    var body: some View {
        List(assignments, selection: $navigationState.selectedItemID) { assignment in
            AssignmentRowView(assignment: assignment)
                .tag(assignment.id)
        }
        .navigationTitle("Assignments")
    }
}

struct AssignmentRowView: View {
    let assignment: Assignment

    var body: some View {
        VStack(alignment: .leading) {
            Text(assignment.name ?? "Unnamed Assignment")
                .font(.headline)
            Text(assignment.startDate, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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

### Step 7: Basic Commands

**LocumTrackerMac/App/AppCommands.swift**
```swift
import SwiftUI

/// Custom menu commands for the app
struct AppCommands: Commands {
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
            Toggle("Show Inspector", isOn: .constant(true))
                .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}

extension Notification.Name {
    static let newAssignment = Notification.Name("newAssignment")
    static let newLocation = Notification.Name("newLocation")
    static let newReceipt = Notification.Name("newReceipt")
}
```

### Step 8: Settings Window

**LocumTrackerMac/Settings/SettingsWindowView.swift**
```swift
import SwiftUI

struct SettingsWindowView: View {
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
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsTab: View {
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

struct ProfileSettingsTab: View {
    var body: some View {
        Text("Profile settings - connects to LocumProfile")
            .padding()
    }
}

struct SyncSettingsTab: View {
    var body: some View {
        Text("CloudKit sync status and settings")
            .padding()
    }
}
```

### Step 9: Configure Entitlements

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
