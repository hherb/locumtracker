# Phase 5: Polish & Integration

*Final refinements, settings, performance optimization, and TestFlight preparation*

## Objectives

- Complete Settings window with all preferences
- Integrate profile and sync settings
- Implement window state restoration
- Add Touch Bar support (legacy Macs)
- Performance optimization
- Accessibility improvements
- App Store preparation

## Implementation Steps

### Step 1: Complete Settings Window

**LocumTrackerMac/Settings/SettingsWindowView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerStorage

struct SettingsWindowView: View {
    private enum Tabs: Hashable {
        case general
        case profile
        case defaults
        case sync
        case export
        case about
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

            DefaultsSettingsTab()
                .tabItem {
                    Label("Defaults", systemImage: "slider.horizontal.3")
                }
                .tag(Tabs.defaults)

            SyncSettingsTab()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(Tabs.sync)

            ExportSettingsTab()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(Tabs.export)

            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(Tabs.about)
        }
        .frame(width: 550, height: 450)
    }
}

// MARK: - General Settings

struct GeneralSettingsTab: View {
    @AppStorage("defaultMMMClassification") private var defaultMMM = 3
    @AppStorage("showInspectorByDefault") private var showInspector = true
    @AppStorage("confirmBeforeDelete") private var confirmDelete = true
    @AppStorage("autoSaveInterval") private var autoSaveInterval = 30

    var body: some View {
        Form {
            Section("Display") {
                Toggle("Show Inspector panel by default", isOn: $showInspector)

                Picker("Default MMM Classification", selection: $defaultMMM) {
                    ForEach(1...7, id: \.self) { mmm in
                        Text("MMM \(mmm)").tag(mmm)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Confirm before deleting items", isOn: $confirmDelete)

                Picker("Auto-save interval", selection: $autoSaveInterval) {
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                }
            }

            Section("Startup") {
                Toggle("Restore windows on launch", isOn: .constant(true))
                Toggle("Check for updates automatically", isOn: .constant(true))
            }
        }
        .padding()
    }
}

// MARK: - Profile Settings

struct ProfileSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [LocumProfile]

    private var profile: LocumProfile? {
        profiles.first
    }

    @State private var name = ""
    @State private var abn = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var bankName = ""
    @State private var bsb = ""
    @State private var accountNumber = ""
    @State private var accountName = ""

    var body: some View {
        Form {
            Section("Personal Information") {
                TextField("Full Name", text: $name)
                TextField("ABN", text: $abn)
                    .textContentType(.creditCardNumber)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                TextField("Phone", text: $phone)
                    .textContentType(.telephoneNumber)
                TextField("Address", text: $address, axis: .vertical)
                    .lineLimit(3)
            }

            Section("Payment Details") {
                TextField("Bank Name", text: $bankName)
                HStack {
                    TextField("BSB", text: $bsb)
                        .frame(width: 100)
                    TextField("Account Number", text: $accountNumber)
                }
                TextField("Account Name", text: $accountName)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Save Changes") {
                        saveProfile()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .onAppear {
            loadProfile()
        }
    }

    private func loadProfile() {
        guard let profile = profile else { return }
        name = profile.name
        abn = profile.abn ?? ""
        email = profile.email ?? ""
        phone = profile.phone ?? ""
        address = profile.address ?? ""
        // Load payment details from JSON
    }

    private func saveProfile() {
        let existingProfile = profile ?? LocumProfile(name: name)

        existingProfile.name = name
        existingProfile.abn = abn.isEmpty ? nil : abn
        existingProfile.email = email.isEmpty ? nil : email
        existingProfile.phone = phone.isEmpty ? nil : phone
        existingProfile.address = address.isEmpty ? nil : address
        // Save payment details as JSON

        if profile == nil {
            modelContext.insert(existingProfile)
        }

        try? modelContext.save()
    }
}

// MARK: - Defaults Settings

struct DefaultsSettingsTab: View {
    @AppStorage("defaultHourlyRate") private var hourlyRate = 150.0
    @AppStorage("defaultDailyRate") private var dailyRate = 1200.0
    @AppStorage("defaultOnCallMultiplier") private var onCallMultiplier = 0.25
    @AppStorage("defaultCallOutMultiplier") private var callOutMultiplier = 0.50
    @AppStorage("defaultSessionDuration") private var sessionDuration = 8

    var body: some View {
        Form {
            Section("Rate Defaults") {
                HStack {
                    Text("Default Hourly Rate")
                    Spacer()
                    TextField("", value: $hourlyRate, format: .currency(code: "AUD"))
                        .frame(width: 120)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Default Daily Rate")
                    Spacer()
                    TextField("", value: $dailyRate, format: .currency(code: "AUD"))
                        .frame(width: 120)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Multipliers") {
                HStack {
                    Text("On-Call Rate Multiplier")
                    Spacer()
                    TextField("", value: $onCallMultiplier, format: .percent)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Call-Out Rate Multiplier")
                    Spacer()
                    TextField("", value: $callOutMultiplier, format: .percent)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Session Defaults") {
                Picker("Default Session Duration", selection: $sessionDuration) {
                    Text("4 hours").tag(4)
                    Text("6 hours").tag(6)
                    Text("8 hours").tag(8)
                    Text("10 hours").tag(10)
                    Text("12 hours").tag(12)
                }
            }
        }
        .padding()
    }
}

// MARK: - Sync Settings

struct SyncSettingsTab: View {
    @StateObject private var syncMonitor = CloudKitSyncMonitor()

    var body: some View {
        Form {
            Section("iCloud Sync Status") {
                HStack {
                    Circle()
                        .fill(syncStatusColor)
                        .frame(width: 12, height: 12)
                    Text(syncStatusText)
                    Spacer()
                }

                if let lastSync = syncMonitor.lastSyncDate {
                    HStack {
                        Text("Last synced")
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Sync Options") {
                Toggle("Enable iCloud Sync", isOn: .constant(true))

                Button("Sync Now") {
                    syncMonitor.requestSync()
                }
                .disabled(syncMonitor.isSyncing)
            }

            Section("Data Management") {
                Button("Export All Data...") {
                    exportAllData()
                }

                Button("Import Data...") {
                    importData()
                }

                Divider()

                Button("Reset Local Data", role: .destructive) {
                    // Show confirmation dialog
                }
            }
        }
        .padding()
    }

    private var syncStatusColor: Color {
        switch syncMonitor.syncStatus {
        case .synced: return .green
        case .syncing: return .blue
        case .error: return .red
        case .offline: return .gray
        }
    }

    private var syncStatusText: String {
        switch syncMonitor.syncStatus {
        case .synced: return "Up to date"
        case .syncing: return "Syncing..."
        case .error(let message): return "Error: \(message)"
        case .offline: return "Offline"
        }
    }

    private func exportAllData() {
        // Export implementation
    }

    private func importData() {
        // Import implementation
    }
}

// MARK: - Export Settings

struct ExportSettingsTab: View {
    @AppStorage("defaultExportFormat") private var exportFormat = "csv"
    @AppStorage("includeReceiptImages") private var includeImages = true
    @AppStorage("exportDateFormat") private var dateFormat = "yyyy-MM-dd"
    @AppStorage("currencySymbol") private var currencySymbol = "$"

    var body: some View {
        Form {
            Section("Default Export Format") {
                Picker("Format", selection: $exportFormat) {
                    Text("CSV").tag("csv")
                    Text("Excel").tag("xlsx")
                    Text("PDF").tag("pdf")
                }
                .pickerStyle(.radioGroup)
            }

            Section("Export Options") {
                Toggle("Include receipt images in exports", isOn: $includeImages)

                Picker("Date Format", selection: $dateFormat) {
                    Text("2024-01-15 (ISO)").tag("yyyy-MM-dd")
                    Text("15/01/2024 (AU)").tag("dd/MM/yyyy")
                    Text("Jan 15, 2024").tag("MMM d, yyyy")
                }

                Picker("Currency Symbol", selection: $currencySymbol) {
                    Text("$ (Dollar)").tag("$")
                    Text("AUD").tag("AUD")
                }
            }

            Section("Invoice Defaults") {
                TextField("Default Payment Terms (days)", value: .constant(14), format: .number)
                TextField("Invoice Number Prefix", text: .constant("INV-"))
            }
        }
        .padding()
    }
}

// MARK: - About Tab

struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "stethoscope")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("LocumTracker")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(appVersion) (\(buildNumber))")
                .foregroundStyle(.secondary)

            Text("Work tracking for Australian locum doctors")
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)

            VStack(spacing: 8) {
                Link("Website", destination: URL(string: "https://locumtracker.app")!)
                Link("Privacy Policy", destination: URL(string: "https://locumtracker.app/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://locumtracker.app/terms")!)
            }

            Spacer()

            Text("© 2025 Dr Horst Herb")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Licensed under AGPL-3.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
```

### Step 2: Window State Restoration

**LocumTrackerMac/App/WindowRestoration.swift**
```swift
import SwiftUI
import AppKit

@Observable
class WindowRestorationManager {
    static let shared = WindowRestorationManager()

    private let defaults = UserDefaults.standard
    private let stateKey = "windowStates"

    struct WindowState: Codable, Hashable {
        var windowType: WindowType
        var identifier: String
        var frame: CodableRect?
        var isMinimized: Bool

        enum WindowType: String, Codable {
            case main
            case assignment
            case report
            case invoice
        }
    }

    struct CodableRect: Codable, Hashable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double

        init(_ rect: CGRect) {
            self.x = rect.origin.x
            self.y = rect.origin.y
            self.width = rect.size.width
            self.height = rect.size.height
        }

        var cgRect: CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }
    }

    func saveWindowStates() {
        var states: [WindowState] = []

        for window in NSApp.windows {
            guard let identifier = window.identifier?.rawValue else { continue }

            let state = WindowState(
                windowType: windowType(for: identifier),
                identifier: identifier,
                frame: CodableRect(window.frame),
                isMinimized: window.isMiniaturized
            )
            states.append(state)
        }

        if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: stateKey)
        }
    }

    func restoreWindowStates() {
        guard let data = defaults.data(forKey: stateKey),
              let states = try? JSONDecoder().decode([WindowState].self, from: data) else {
            return
        }

        for state in states {
            restoreWindow(state)
        }
    }

    private func windowType(for identifier: String) -> WindowState.WindowType {
        if identifier.starts(with: "assignment-") { return .assignment }
        if identifier.starts(with: "report-") { return .report }
        if identifier.starts(with: "invoice-") { return .invoice }
        return .main
    }

    private func restoreWindow(_ state: WindowState) {
        // Implementation to restore specific window types
    }
}

// MARK: - App Delegate Integration

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        WindowRestorationManager.shared.saveWindowStates()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        WindowRestorationManager.shared.restoreWindowStates()
    }
}
```

### Step 3: Touch Bar Support (Legacy)

**LocumTrackerMac/TouchBar/TouchBarProvider.swift**
```swift
import SwiftUI
import AppKit

struct TouchBarModifier: ViewModifier {
    let navigationState: NavigationState

    func body(content: Content) -> some View {
        content
            .touchBar {
                TouchBar(id: "main") {
                    // Navigation buttons
                    Button(action: { navigationState.selectedSection = .assignments }) {
                        Label("Assignments", systemImage: "calendar")
                    }

                    Button(action: { navigationState.selectedSection = .receipts }) {
                        Label("Receipts", systemImage: "doc.text")
                    }

                    Button(action: { navigationState.selectedSection = .earnings }) {
                        Label("Earnings", systemImage: "dollarsign.circle")
                    }

                    Spacer(minLength: 0)

                    // Quick add
                    Button(action: { AppAction.newAssignment.post() }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
    }
}

extension View {
    func withTouchBar(navigationState: NavigationState) -> some View {
        modifier(TouchBarModifier(navigationState: navigationState))
    }
}
```

### Step 4: Accessibility Improvements

**LocumTrackerMac/Accessibility/AccessibilityModifiers.swift**
```swift
import SwiftUI

extension View {
    func accessibleAssignment(_ assignment: Assignment, locations: [Location]) -> some View {
        let locationName = locations.first { $0.id == assignment.locationId }?.name ?? "Unknown"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        return self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(assignment.name ?? "Assignment") at \(locationName)")
            .accessibilityValue("From \(dateFormatter.string(from: assignment.startDate)) to \(dateFormatter.string(from: assignment.endDate))")
            .accessibilityHint("Double-tap to view details")
    }

    func accessibleReceipt(_ receipt: Receipt) -> some View {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let amountFormatter = NumberFormatter()
        amountFormatter.numberStyle = .currency
        amountFormatter.currencyCode = "AUD"

        return self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(receipt.merchant ?? "Receipt") for \(amountFormatter.string(from: receipt.amount as NSDecimalNumber) ?? "")")
            .accessibilityValue("\(receipt.category.rawValue), \(dateFormatter.string(from: receipt.date))")
    }

    func accessibleEarnings(_ amount: Decimal) -> some View {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"

        return self
            .accessibilityLabel("Earnings")
            .accessibilityValue(formatter.string(from: amount as NSDecimalNumber) ?? "")
    }
}

// MARK: - VoiceOver Announcements

enum AccessibilityAnnouncement {
    static func announce(_ message: String) {
        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: message]
        )
    }

    static func itemAdded(_ itemType: String) {
        announce("New \(itemType) added")
    }

    static func itemDeleted(_ itemType: String) {
        announce("\(itemType) deleted")
    }

    static func syncComplete() {
        announce("Sync complete")
    }
}
```

### Step 5: Performance Optimization

**LocumTrackerMac/Performance/LazyLoadingModifier.swift**
```swift
import SwiftUI

struct LazyLoadingModifier<Content: View>: ViewModifier {
    let threshold: Int
    let content: () -> Content

    @State private var isLoaded = false

    func body(content: Content) -> some View {
        if isLoaded {
            self.content()
        } else {
            ProgressView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isLoaded = true
                    }
                }
        }
    }
}

// MARK: - Query Optimization

extension View {
    /// Optimizes large list rendering with pagination
    func paginatedList<T: Identifiable>(
        items: [T],
        pageSize: Int = 50,
        @ViewBuilder rowContent: @escaping (T) -> some View
    ) -> some View {
        PaginatedListView(items: items, pageSize: pageSize, rowContent: rowContent)
    }
}

struct PaginatedListView<T: Identifiable, RowContent: View>: View {
    let items: [T]
    let pageSize: Int
    let rowContent: (T) -> RowContent

    @State private var loadedCount: Int

    init(items: [T], pageSize: Int, @ViewBuilder rowContent: @escaping (T) -> RowContent) {
        self.items = items
        self.pageSize = pageSize
        self.rowContent = rowContent
        self._loadedCount = State(initialValue: min(pageSize, items.count))
    }

    var body: some View {
        List {
            ForEach(items.prefix(loadedCount)) { item in
                rowContent(item)
            }

            if loadedCount < items.count {
                ProgressView()
                    .onAppear {
                        loadMore()
                    }
            }
        }
    }

    private func loadMore() {
        let newCount = min(loadedCount + pageSize, items.count)
        withAnimation {
            loadedCount = newCount
        }
    }
}

// MARK: - Memory Management

class MemoryManager {
    static let shared = MemoryManager()

    func clearImageCache() {
        // Clear any cached receipt images
        URLCache.shared.removeAllCachedResponses()
    }

    func reduceMemoryUsage() {
        clearImageCache()
        // Additional cleanup
    }
}
```

### Step 6: App Store Preparation

**LocumTrackerMac/Resources/Info.plist additions**
```xml
<!-- Privacy descriptions -->
<key>NSCameraUsageDescription</key>
<string>LocumTracker uses the camera to capture receipt images.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>LocumTracker accesses photos to import receipt images.</string>

<!-- App Transport Security -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>

<!-- Hardened Runtime -->
<key>com.apple.security.hardened-runtime</key>
<true/>
```

**Build Configuration Checklist**

```
☐ Signing & Capabilities
  ☐ Team selected
  ☐ Bundle ID: com.hherb.locumtracker.mac
  ☐ iCloud capability enabled
  ☐ CloudKit container configured

☐ Build Settings
  ☐ Deployment target: macOS 14.0
  ☐ Build number incremented
  ☐ Version string set

☐ Archive Settings
  ☐ Code signing identity: Developer ID
  ☐ Notarization enabled
```

### Step 7: Help Documentation

**LocumTrackerMac/Resources/LocumTrackerMac.help/**

Create Help Book structure:
```
LocumTrackerMac.help/
├── Contents/
│   ├── Info.plist
│   └── Resources/
│       ├── index.html
│       ├── getting-started.html
│       ├── assignments.html
│       ├── receipts.html
│       ├── fps-tracking.html
│       ├── reporting.html
│       └── styles.css
```

### Step 8: Final Testing

**TestFlight Preparation Checklist**

```
☐ Core Functionality
  ☐ All views load correctly
  ☐ Data persists across launches
  ☐ CloudKit sync works with iOS app
  ☐ All keyboard shortcuts functional
  ☐ Context menus work

☐ Window Management
  ☐ Multiple windows open/close properly
  ☐ Window positions restore
  ☐ Settings window saves preferences

☐ Reporting
  ☐ All report types generate
  ☐ CSV export produces valid files
  ☐ PDF invoices render correctly
  ☐ Print functionality works

☐ Performance
  ☐ App launches in < 3 seconds
  ☐ Large lists scroll smoothly
  ☐ Memory usage stays reasonable

☐ Accessibility
  ☐ VoiceOver navigates correctly
  ☐ All interactive elements labeled
  ☐ Keyboard navigation complete

☐ Edge Cases
  ☐ Empty states display properly
  ☐ Error messages are helpful
  ☐ Offline mode works
```

## Files Created/Modified

```
LocumTrackerMac/
├── Settings/
│   └── SettingsWindowView.swift         (complete implementation)
├── App/
│   ├── WindowRestoration.swift          (new)
│   └── AppDelegate.swift                (new)
├── TouchBar/
│   └── TouchBarProvider.swift           (new)
├── Accessibility/
│   └── AccessibilityModifiers.swift     (new)
├── Performance/
│   └── LazyLoadingModifier.swift        (new)
└── Resources/
    ├── Info.plist                       (updated)
    └── LocumTrackerMac.help/            (new directory)
```

## Estimated Scope

- **Files modified/created**: ~15
- **Lines of code**: ~800-1000
- **Help pages**: ~6

## Completion Criteria

### Ready for TestFlight

- [ ] All phases 1-5 complete
- [ ] No critical bugs
- [ ] Performance acceptable
- [ ] Accessibility audit passed
- [ ] Help documentation complete
- [ ] App icon and assets finalized
- [ ] Privacy policy URL configured
- [ ] Support URL configured

### Ready for App Store

- [ ] TestFlight feedback addressed
- [ ] Screenshots prepared
- [ ] App description written
- [ ] Keywords optimized
- [ ] Review notes prepared

## Summary

Phase 5 completes the macOS app with:
- Full settings integration
- Professional polish
- Accessibility compliance
- Performance optimization
- App Store readiness

The macOS app is now a full-featured companion to the iOS app, leveraging the larger screen for enhanced productivity while sharing core business logic through the package architecture.
