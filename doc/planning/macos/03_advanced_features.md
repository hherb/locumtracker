# Phase 3: Advanced macOS Features

*Keyboard shortcuts, context menus, drag-and-drop, and multi-window support*

## Objectives

- Implement comprehensive keyboard navigation
- Add context menus to all interactive elements
- Enable drag-and-drop for receipts and reordering
- Support multiple windows for parallel workflows
- Implement Quick Look for receipt previews

## Keyboard Shortcuts

### Global Shortcuts (App-wide)

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New Assignment |
| `Cmd+Shift+N` | New Location |
| `Cmd+Option+N` | New Receipt |
| `Cmd+1-6` | Switch sidebar section |
| `Cmd+Option+I` | Toggle inspector |
| `Cmd+,` | Open Settings |
| `Cmd+F` | Focus search field |
| `Cmd+R` | Refresh data |

### Navigation Shortcuts

| Shortcut | Action |
|----------|--------|
| `↑/↓` | Navigate list items |
| `Enter` | Open selected item |
| `Space` | Quick Look (receipts) |
| `Cmd+[` | Go back |
| `Cmd+]` | Go forward |
| `Delete` | Delete selected item |

### Editing Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+E` | Edit selected item |
| `Cmd+D` | Duplicate selected |
| `Cmd+S` | Save changes |
| `Escape` | Cancel editing |

## Implementation Steps

### Step 1: Enhanced App Commands

**LocumTrackerMac/App/AppCommands.swift**
```swift
import SwiftUI

struct AppCommands: Commands {
    @FocusedBinding(\.navigationState) var navigationState: NavigationState?

    var body: some Commands {
        // New Item Menu
        CommandGroup(replacing: .newItem) {
            newItemMenu
        }

        // Navigation Menu
        CommandMenu("Navigate") {
            navigationMenu
        }

        // View Menu Additions
        CommandGroup(after: .sidebar) {
            viewMenuItems
        }

        // Edit Menu Additions
        CommandGroup(after: .pasteboard) {
            editMenuItems
        }
    }

    @ViewBuilder
    private var newItemMenu: some View {
        Button("New Assignment") {
            AppAction.newAssignment.post()
        }
        .keyboardShortcut("n", modifiers: [.command])

        Button("New Location") {
            AppAction.newLocation.post()
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("New Receipt") {
            AppAction.newReceipt.post()
        }
        .keyboardShortcut("n", modifiers: [.command, .option])

        Button("New Session") {
            AppAction.newSession.post()
        }
        .keyboardShortcut("n", modifiers: [.command, .control])
        .disabled(navigationState?.selectedSection != .assignments)
    }

    @ViewBuilder
    private var navigationMenu: some View {
        Button("Assignments") {
            navigationState?.selectedSection = .assignments
        }
        .keyboardShortcut("1", modifiers: .command)

        Button("Locations") {
            navigationState?.selectedSection = .locations
        }
        .keyboardShortcut("2", modifiers: .command)

        Button("Receipts") {
            navigationState?.selectedSection = .receipts
        }
        .keyboardShortcut("3", modifiers: .command)

        Button("FPS Quota") {
            navigationState?.selectedSection = .fpsQuota
        }
        .keyboardShortcut("4", modifiers: .command)

        Button("Earnings") {
            navigationState?.selectedSection = .earnings
        }
        .keyboardShortcut("5", modifiers: .command)

        Button("Reports") {
            navigationState?.selectedSection = .reports
        }
        .keyboardShortcut("6", modifiers: .command)

        Divider()

        Button("Go Back") {
            AppAction.goBack.post()
        }
        .keyboardShortcut("[", modifiers: .command)

        Button("Go Forward") {
            AppAction.goForward.post()
        }
        .keyboardShortcut("]", modifiers: .command)
    }

    @ViewBuilder
    private var viewMenuItems: some View {
        Toggle("Show Inspector", isOn: Binding(
            get: { navigationState?.showInspector ?? true },
            set: { navigationState?.showInspector = $0 }
        ))
        .keyboardShortcut("i", modifiers: [.command, .option])

        Divider()

        Button("Refresh") {
            AppAction.refresh.post()
        }
        .keyboardShortcut("r", modifiers: .command)
    }

    @ViewBuilder
    private var editMenuItems: some View {
        Divider()

        Button("Duplicate") {
            AppAction.duplicate.post()
        }
        .keyboardShortcut("d", modifiers: .command)
    }
}

// MARK: - App Actions

enum AppAction: String {
    case newAssignment
    case newLocation
    case newReceipt
    case newSession
    case goBack
    case goForward
    case refresh
    case duplicate
    case edit
    case delete

    var notificationName: Notification.Name {
        Notification.Name("AppAction.\(rawValue)")
    }

    func post(object: Any? = nil) {
        NotificationCenter.default.post(name: notificationName, object: object)
    }
}

// MARK: - Focus Key

struct NavigationStateFocusKey: FocusedValueKey {
    typealias Value = Binding<NavigationState>
}

extension FocusedValues {
    var navigationState: Binding<NavigationState>? {
        get { self[NavigationStateFocusKey.self] }
        set { self[NavigationStateFocusKey.self] = newValue }
    }
}
```

### Step 2: Keyboard Handler View Modifier

**LocumTrackerMac/Utilities/KeyboardHandler.swift**
```swift
import SwiftUI

/// View modifier that adds keyboard navigation to list views.
///
/// Handles arrow key navigation, Enter to open, Delete to remove,
/// and Space for quick look actions.
///
/// - Parameters:
///   - selectedItemID: Binding to the currently selected item's UUID.
///   - itemIDs: Array of UUIDs representing the navigable items in order.
///   - onEnter: Optional callback when Enter is pressed on a selection.
///   - onDelete: Optional callback when Delete is pressed on a selection.
///   - onSpace: Optional callback when Space is pressed on a selection.
struct KeyboardHandler: ViewModifier {
    @Binding var selectedItemID: UUID?
    let itemIDs: [UUID]
    let onEnter: ((UUID) -> Void)?
    let onDelete: ((UUID) -> Void)?
    let onSpace: ((UUID) -> Void)?

    func body(content: Content) -> some View {
        content
            .onKeyPress(.upArrow) {
                navigateUp()
                return .handled
            }
            .onKeyPress(.downArrow) {
                navigateDown()
                return .handled
            }
            .onKeyPress(.return) {
                if let id = selectedItemID {
                    onEnter?(id)
                }
                return .handled
            }
            .onKeyPress(.delete) {
                if let id = selectedItemID {
                    onDelete?(id)
                }
                return .handled
            }
            .onKeyPress(.space) {
                if let id = selectedItemID {
                    onSpace?(id)
                }
                return .handled
            }
    }

    /// Navigate to the previous item in the list.
    private func navigateUp() {
        guard let currentID = selectedItemID,
              let currentIndex = itemIDs.firstIndex(of: currentID),
              currentIndex > 0 else { return }
        selectedItemID = itemIDs[currentIndex - 1]
    }

    /// Navigate to the next item in the list.
    private func navigateDown() {
        guard let currentID = selectedItemID,
              let currentIndex = itemIDs.firstIndex(of: currentID),
              currentIndex < itemIDs.count - 1 else { return }
        selectedItemID = itemIDs[currentIndex + 1]
    }
}

extension View {
    /// Adds keyboard navigation support to a view.
    ///
    /// - Parameters:
    ///   - selection: Binding to the selected item's UUID.
    ///   - items: Array of identifiable items to navigate through.
    ///   - onEnter: Optional callback when Enter is pressed.
    ///   - onDelete: Optional callback when Delete is pressed.
    ///   - onSpace: Optional callback when Space is pressed.
    /// - Returns: A view with keyboard navigation enabled.
    func keyboardNavigation<T: Identifiable>(
        selection: Binding<UUID?>,
        items: [T],
        onEnter: ((UUID) -> Void)? = nil,
        onDelete: ((UUID) -> Void)? = nil,
        onSpace: ((UUID) -> Void)? = nil
    ) -> some View where T.ID == UUID {
        modifier(KeyboardHandler(
            selectedItemID: selection,
            itemIDs: items.map(\.id),
            onEnter: onEnter,
            onDelete: onDelete,
            onSpace: onSpace
        ))
    }
}
```

### Step 3: Context Menus

**LocumTrackerMac/Views/Assignments/AssignmentContextMenu.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore

struct AssignmentContextMenu: View {
    let assignment: Assignment
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onGenerateInvoice: () -> Void
    let onExport: () -> Void

    var body: some View {
        Group {
            Button(action: onEdit) {
                Label("Edit Assignment", systemImage: "pencil")
            }

            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Divider()

            Menu("Add") {
                Button("Add Session") {
                    AppAction.newSession.post(object: assignment.id)
                }
                Button("Add Daily Record") {
                    // Add daily record action
                }
            }

            Divider()

            Menu("Status") {
                ForEach(AssignmentStatus.allCases, id: \.self) { status in
                    Button(status.rawValue.capitalized) {
                        assignment.status = status
                    }
                    .disabled(assignment.status == status)
                }
            }

            Divider()

            Button(action: onGenerateInvoice) {
                Label("Generate Invoice", systemImage: "doc.text")
            }

            Button(action: onExport) {
                Label("Export to CSV", systemImage: "arrow.up.doc")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete Assignment", systemImage: "trash")
            }
        }
    }
}

// Usage in AssignmentListView:
// .contextMenu {
//     AssignmentContextMenu(
//         assignment: assignment,
//         onEdit: { ... },
//         ...
//     )
// }
```

**LocumTrackerMac/Views/Receipts/ReceiptContextMenu.swift**
```swift
import SwiftUI
import LocumTrackerCore

struct ReceiptContextMenu: View {
    let receipt: Receipt
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onQuickLook: () -> Void
    let onExport: () -> Void

    var body: some View {
        Group {
            Button(action: onQuickLook) {
                Label("Quick Look", systemImage: "eye")
            }

            Divider()

            Button(action: onEdit) {
                Label("Edit Receipt", systemImage: "pencil")
            }

            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Divider()

            Menu("Category") {
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    Button(category.rawValue.capitalized) {
                        receipt.category = category
                    }
                    .disabled(receipt.category == category)
                }
            }

            Toggle("Tax Deductible", isOn: Binding(
                get: { receipt.isTaxDeductible },
                set: { receipt.isTaxDeductible = $0 }
            ))

            Divider()

            Button(action: onExport) {
                Label("Export Image", systemImage: "photo")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete Receipt", systemImage: "trash")
            }
        }
    }
}
```

### Step 4: Drag and Drop

**LocumTrackerMac/Views/Receipts/ReceiptDropHandler.swift**
```swift
import SwiftUI
import UniformTypeIdentifiers
import LocumTrackerCore

struct ReceiptDropHandler: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @State private var isTargeted = false
    let assignmentID: UUID?

    func body(content: Content) -> some View {
        content
            .dropDestination(for: Data.self) { items, location in
                handleDrop(items: items)
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.blue, lineWidth: 2)
                        .background(.blue.opacity(0.1))
                }
            }
    }

    private func handleDrop(items: [Data]) -> Bool {
        for imageData in items {
            createReceipt(from: imageData)
        }
        return true
    }

    private func createReceipt(from imageData: Data) {
        let receipt = Receipt(
            amount: 0,
            date: Date(),
            category: .other,
            imageData: imageData
        )
        receipt.assignmentId = assignmentID

        modelContext.insert(receipt)

        // Trigger OCR processing
        Task {
            await processReceiptOCR(receipt: receipt)
        }
    }

    @MainActor
    private func processReceiptOCR(receipt: Receipt) async {
        // Use LocumTrackerOCR to extract data
        // Update receipt with extracted merchant, amount, date
    }
}

extension View {
    func receiptDropTarget(assignmentID: UUID? = nil) -> some View {
        modifier(ReceiptDropHandler(assignmentID: assignmentID))
    }
}
```

**LocumTrackerMac/Views/Sessions/SessionReorderHandler.swift**
```swift
import SwiftUI
import LocumTrackerCore

struct SessionReorderHandler: ViewModifier {
    @Binding var sessions: [Session]

    func body(content: Content) -> some View {
        content
            .draggable(sessions) { session in
                SessionDragPreview(session: session)
            }
            .dropDestination(for: Session.self) { droppedSessions, location in
                reorderSessions(droppedSessions, at: location)
            }
    }

    private func reorderSessions(_ droppedSessions: [Session], at location: CGPoint) -> Bool {
        // Calculate insertion index based on location
        // Reorder sessions array
        return true
    }
}

struct SessionDragPreview: View {
    let session: Session

    var body: some View {
        HStack {
            Image(systemName: "clock")
            Text(session.date, style: .date)
            Text("•")
            Text("\(session.durationMinutes / 60)h")
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

### Step 5: Multi-Window Support

**LocumTrackerMac/App/LocumTrackerMacApp.swift** (updated)
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerStorage

@main
struct LocumTrackerMacApp: App {
    var sharedModelContainer: ModelContainer = {
        // ... existing container setup
    }()

    var body: some Scene {
        // Main window
        WindowGroup {
            MainWindowView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            AppCommands()
        }

        // Assignment detail window (opened via double-click or menu)
        WindowGroup("Assignment", for: UUID.self) { $assignmentID in
            if let id = assignmentID {
                AssignmentWindowView(assignmentID: id)
            }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 800, height: 600)

        // Report window
        WindowGroup("Report", for: ReportConfiguration.self) { $config in
            if let config = config {
                ReportWindowView(configuration: config)
            }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1000, height: 700)

        // Invoice window
        WindowGroup("Invoice", for: InvoiceConfiguration.self) { $config in
            if let config = config {
                InvoiceWindowView(configuration: config)
            }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 600, height: 800)

        Settings {
            SettingsWindowView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Window Configurations

struct ReportConfiguration: Hashable, Codable {
    var reportType: ReportType
    var startDate: Date
    var endDate: Date
    var assignmentIDs: [UUID]

    enum ReportType: String, Codable {
        case earnings
        case expenses
        case fpsCompliance
        case taxSummary
    }
}

struct InvoiceConfiguration: Hashable, Codable {
    var assignmentID: UUID
    var includeExpenses: Bool
    var notes: String?
}
```

**LocumTrackerMac/Windows/AssignmentWindowView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore

struct AssignmentWindowView: View {
    let assignmentID: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var assignments: [Assignment]
    @Query private var locations: [Location]

    @State private var showingAddSession = false

    private var assignment: Assignment? {
        assignments.first { $0.id == assignmentID }
    }

    var body: some View {
        if let assignment = assignment {
            HSplitView {
                // Left: Sessions list
                SessionsListPanel(assignment: assignment)
                    .frame(minWidth: 250, maxWidth: 350)

                // Right: Detail and actions
                AssignmentDetailPanel(assignment: assignment, locations: locations)
            }
            .navigationTitle(assignment.name ?? "Assignment")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { showingAddSession = true }) {
                        Label("Add Session", systemImage: "plus")
                    }

                    Button(action: generateInvoice) {
                        Label("Generate Invoice", systemImage: "doc.text")
                    }
                }
            }
            .sheet(isPresented: $showingAddSession) {
                AddSessionSheet(assignment: assignment)
            }
        } else {
            ContentUnavailableView(
                "Assignment Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("This assignment may have been deleted.")
            )
        }
    }

    private func generateInvoice() {
        guard let assignment = assignment else { return }
        let config = InvoiceConfiguration(
            assignmentID: assignment.id,
            includeExpenses: true,
            notes: nil
        )
        openWindow(value: config)
    }

    @Environment(\.openWindow) private var openWindow
}

struct SessionsListPanel: View {
    let assignment: Assignment
    @State private var selectedSession: Session?

    var body: some View {
        List(assignment.sessions, selection: $selectedSession) { session in
            SessionRowView(session: session)
                .tag(session)
        }
        .listStyle(.inset)
        .navigationTitle("Sessions")
    }
}

struct AssignmentDetailPanel: View {
    let assignment: Assignment
    let locations: [Location]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary section
                GroupBox("Summary") {
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                        GridRow {
                            Text("Location")
                            Text(locationName)
                        }
                        GridRow {
                            Text("Duration")
                            Text(dateRange)
                        }
                        GridRow {
                            Text("Sessions")
                            Text("\(assignment.sessions.count)")
                        }
                        GridRow {
                            Text("Total Earnings")
                            Text(totalEarnings, format: .currency(code: "AUD"))
                        }
                    }
                }

                // Actions section
                GroupBox("Quick Actions") {
                    HStack {
                        Button("Edit Details") { }
                        Button("Add Session") { }
                        Button("Generate Invoice") { }
                    }
                }
            }
            .padding()
        }
    }

    private var locationName: String {
        locations.first { $0.id == assignment.locationId }?.name ?? "Unknown"
    }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: assignment.startDate)) - \(formatter.string(from: assignment.endDate))"
    }

    private var totalEarnings: Decimal {
        EarningsAggregationService.totalEarnings(for: assignment)
    }
}
```

### Step 6: Quick Look Integration

**LocumTrackerMac/Views/Receipts/ReceiptQuickLook.swift**
```swift
import SwiftUI
import QuickLook
import LocumTrackerCore

struct ReceiptQuickLookButton: View {
    let receipt: Receipt
    @State private var quickLookURL: URL?

    var body: some View {
        Button(action: showQuickLook) {
            Label("Quick Look", systemImage: "eye")
        }
        .keyboardShortcut(.space, modifiers: [])
        .quickLookPreview($quickLookURL)
    }

    private func showQuickLook() {
        guard let imageData = receipt.imageData else { return }

        // Create temporary file for Quick Look
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(receipt.id.uuidString)
            .appendingPathExtension("jpg")

        do {
            try imageData.write(to: tempURL)
            quickLookURL = tempURL
        } catch {
            print("Failed to create temp file for Quick Look: \(error)")
        }
    }
}

// Alternative: Using QLPreviewPanel directly for more control
class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var previewItems: [QLPreviewItem] = []

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewItems.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewItems[index]
    }
}
```

### Step 7: Window State Restoration

**LocumTrackerMac/Utilities/WindowStateManager.swift**
```swift
import SwiftUI

@Observable
class WindowStateManager {
    static let shared = WindowStateManager()

    private let defaults = UserDefaults.standard
    private let openWindowsKey = "openWindows"

    struct WindowState: Codable {
        var windowType: WindowType
        var identifier: String
        var frame: CGRect?

        enum WindowType: String, Codable {
            case assignment
            case report
            case invoice
        }
    }

    var openWindows: [WindowState] {
        get {
            guard let data = defaults.data(forKey: openWindowsKey),
                  let windows = try? JSONDecoder().decode([WindowState].self, from: data) else {
                return []
            }
            return windows
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: openWindowsKey)
            }
        }
    }

    func saveWindowState(_ state: WindowState) {
        var windows = openWindows
        if let index = windows.firstIndex(where: { $0.identifier == state.identifier }) {
            windows[index] = state
        } else {
            windows.append(state)
        }
        openWindows = windows
    }

    func removeWindowState(identifier: String) {
        openWindows.removeAll { $0.identifier == identifier }
    }
}
```

## Testing Phase 3

### Keyboard Testing Checklist

- [ ] Cmd+N opens new assignment sheet
- [ ] Cmd+Shift+N opens new location sheet
- [ ] Cmd+1 through Cmd+6 switches sections
- [ ] Arrow keys navigate list items
- [ ] Enter opens selected item
- [ ] Space triggers Quick Look on receipts
- [ ] Delete key deletes selected item (with confirmation)
- [ ] Cmd+, opens Settings
- [ ] Cmd+Option+I toggles inspector

### Context Menu Testing

- [ ] Right-click on assignment shows context menu
- [ ] Right-click on receipt shows context menu
- [ ] Right-click on location shows context menu
- [ ] Context menu actions work correctly
- [ ] Status changes apply immediately

### Drag and Drop Testing

- [ ] Drop image files creates new receipt
- [ ] OCR processes dropped images
- [ ] Drag preview shows correct content
- [ ] Drop indicator appears when hovering

### Multi-Window Testing

- [ ] Double-click opens assignment in new window
- [ ] Report window opens with correct data
- [ ] Invoice window generates correctly
- [ ] Windows restore on app relaunch
- [ ] Data syncs across windows

## Files Created/Modified

```
LocumTrackerMac/
├── App/
│   ├── LocumTrackerMacApp.swift    (updated for multi-window)
│   └── AppCommands.swift           (comprehensive shortcuts)
├── Utilities/
│   ├── KeyboardHandler.swift       (new)
│   └── WindowStateManager.swift    (new)
├── Views/
│   ├── Assignments/
│   │   └── AssignmentContextMenu.swift    (new)
│   ├── Receipts/
│   │   ├── ReceiptContextMenu.swift       (new)
│   │   ├── ReceiptDropHandler.swift       (new)
│   │   └── ReceiptQuickLook.swift         (new)
│   └── Sessions/
│       └── SessionReorderHandler.swift    (new)
└── Windows/
    ├── AssignmentWindowView.swift         (new)
    ├── ReportWindowView.swift             (placeholder)
    └── InvoiceWindowView.swift            (placeholder)
```

## Estimated Scope

- **New files**: ~12
- **Modified files**: ~8
- **Lines of code**: ~1000-1200

## Next Phase

Proceed to [Phase 4: Reporting & Export](04_reporting_export.md) to implement the LocumTrackerReporting package and advanced export features.
