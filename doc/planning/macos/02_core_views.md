# Phase 2: Core Views

*Implement full view functionality with macOS-optimized layouts*

## Objectives

- Implement all content views with full functionality
- Create table-based list views with sortable columns
- Build detail views with inline editing
- Implement inspector panels with context-sensitive content
- Maximize code reuse from LocumTrackerUI

## Design Patterns

### Table Views vs. Lists

macOS benefits from table views with sortable columns:

```
┌────────────────────────────────────────────────────────────────┐
│ Location ▼     │ Dates          │ Sessions │ Earnings ▼       │
├────────────────┼────────────────┼──────────┼──────────────────┤
│ Darwin RDH     │ Jun 1 - Jun 14 │ 28       │ $12,450.00       │
│ Alice Springs  │ May 15 - May 28│ 24       │ $10,800.00       │
│ Broome Hospital│ Apr 1 - Apr 7  │ 12       │ $5,400.00        │
└────────────────┴────────────────┴──────────┴──────────────────┘
```

### Inline Editing

Replace sheets with popovers and inline editing for faster workflows:

```swift
// iOS approach (sheet)
.sheet(isPresented: $showingEdit) {
    EditAssignmentSheet(...)
}

// macOS approach (popover or inline)
.popover(isPresented: $showingEdit) {
    EditAssignmentPopover(...)
}
// or direct inline editing in the detail view
```

## Implementation Steps

### Step 1: Shared View Models

Create view models in LocumTrackerUI that both platforms can use:

**Packages/LocumTrackerUI/Sources/LocumTrackerUI/ViewModels/AssignmentViewModel.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore

/// Shared view model for assignment display and editing
@Observable
public final class AssignmentViewModel {
    public var assignment: Assignment
    public var locations: [Location]

    public var isEditing: Bool = false
    public var hasUnsavedChanges: Bool = false

    // Computed display properties
    public var locationName: String {
        locations.first { $0.id == assignment.locationId }?.name ?? "Unknown"
    }

    public var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: assignment.startDate)) - \(formatter.string(from: assignment.endDate))"
    }

    public var totalEarnings: Decimal {
        // Use EarningsAggregationService
        EarningsAggregationService.totalEarnings(for: assignment)
    }

    public var sessionCount: Int {
        assignment.sessions.count
    }

    public init(assignment: Assignment, locations: [Location]) {
        self.assignment = assignment
        self.locations = locations
    }
}
```

### Step 2: Assignment List View (Table-Based)

**LocumTrackerMac/Views/Assignments/AssignmentListView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

struct AssignmentListView: View {
    @Bindable var navigationState: NavigationState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]
    @Query private var locations: [Location]

    @State private var sortOrder = [KeyPathComparator(\Assignment.startDate, order: .reverse)]
    @State private var searchText = ""
    @State private var showingAddSheet = false

    private var filteredAssignments: [Assignment] {
        if searchText.isEmpty {
            return assignments
        }
        return assignments.filter { assignment in
            let locationName = locations.first { $0.id == assignment.locationId }?.name ?? ""
            return locationName.localizedCaseInsensitiveContains(searchText) ||
                   (assignment.name?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Table(filteredAssignments, selection: $navigationState.selectedItemID, sortOrder: $sortOrder) {
            TableColumn("Assignment", value: \.startDate) { assignment in
                AssignmentNameCell(assignment: assignment, locations: locations)
            }
            .width(min: 150, ideal: 200)

            TableColumn("Location") { assignment in
                Text(locationName(for: assignment))
            }
            .width(min: 100, ideal: 150)

            TableColumn("Dates") { assignment in
                Text(dateRange(for: assignment))
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 160)

            TableColumn("Status") { assignment in
                StatusBadge(status: assignment.status)
            }
            .width(60)

            TableColumn("Sessions") { assignment in
                Text("\(assignment.sessions.count)")
                    .monospacedDigit()
            }
            .width(70)

            TableColumn("Earnings", value: \.startDate) { assignment in
                Text(totalEarnings(for: assignment), format: .currency(code: "AUD"))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 110)
        }
        .onChange(of: sortOrder) { _, newOrder in
            // Apply sort order
        }
        .searchable(text: $searchText, prompt: "Search assignments...")
        .navigationTitle("Assignments")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("New Assignment", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddAssignmentSheet(isPresented: $showingAddSheet, locations: locations)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            contextMenuItems(for: ids)
        }
    }

    // MARK: - Helper Methods

    private func locationName(for assignment: Assignment) -> String {
        locations.first { $0.id == assignment.locationId }?.name ?? "Unknown"
    }

    private func dateRange(for assignment: Assignment) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: assignment.startDate)) - \(formatter.string(from: assignment.endDate))"
    }

    private func totalEarnings(for assignment: Assignment) -> Decimal {
        EarningsAggregationService.totalEarnings(for: assignment)
    }

    @ViewBuilder
    private func contextMenuItems(for ids: Set<UUID>) -> some View {
        Button("Edit") {
            // Edit selected assignment
        }
        Button("Duplicate") {
            // Duplicate assignment
        }
        Divider()
        Button("Delete", role: .destructive) {
            deleteAssignments(ids: ids)
        }
    }

    private func deleteAssignments(ids: Set<UUID>) {
        for assignment in assignments where ids.contains(assignment.id) {
            modelContext.delete(assignment)
        }
    }
}

struct AssignmentNameCell: View {
    let assignment: Assignment
    let locations: [Location]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(assignment.name ?? "Unnamed")
                .fontWeight(.medium)
            if let location = locations.first(where: { $0.id == assignment.locationId }) {
                HStack(spacing: 4) {
                    MMMBadge(classification: location.mmmClassification)
                    Text(location.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: AssignmentStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .active: return .green.opacity(0.2)
        case .completed: return .blue.opacity(0.2)
        case .pending: return .orange.opacity(0.2)
        case .cancelled: return .gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .active: return .green
        case .completed: return .blue
        case .pending: return .orange
        case .cancelled: return .gray
        }
    }
}
```

### Step 3: Assignment Detail View

**LocumTrackerMac/Views/Assignments/AssignmentDetailView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

struct AssignmentDetailView: View {
    @Bindable var navigationState: NavigationState
    @Environment(\.modelContext) private var modelContext
    @Query private var assignments: [Assignment]
    @Query private var locations: [Location]

    @State private var isEditing = false
    @State private var showingAddSession = false

    private var assignment: Assignment? {
        guard let id = navigationState.selectedItemID else { return nil }
        return assignments.first { $0.id == id }
    }

    var body: some View {
        if let assignment = assignment {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection(assignment)
                    Divider()
                    sessionsSection(assignment)
                    Divider()
                    financialSection(assignment)
                }
                .padding()
            }
            .navigationTitle(assignment.name ?? "Assignment")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { showingAddSession = true }) {
                        Label("Add Session", systemImage: "plus.circle")
                    }

                    Button(action: { isEditing.toggle() }) {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
            .popover(isPresented: $isEditing) {
                EditAssignmentPopover(assignment: assignment, locations: locations)
                    .frame(width: 400, height: 500)
            }
            .sheet(isPresented: $showingAddSession) {
                AddSessionSheet(assignment: assignment)
            }
        } else {
            ContentUnavailableView(
                "Select an Assignment",
                systemImage: "calendar",
                description: Text("Choose an assignment from the list")
            )
        }
    }

    @ViewBuilder
    private func headerSection(_ assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(assignment.name ?? "Unnamed Assignment")
                        .font(.title)
                        .fontWeight(.bold)

                    if let location = locations.first(where: { $0.id == assignment.locationId }) {
                        HStack {
                            MMMBadge(classification: location.mmmClassification)
                            Text(location.name)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                StatusBadge(status: assignment.status)
            }

            HStack(spacing: 20) {
                Label {
                    Text(assignment.startDate, style: .date)
                } icon: {
                    Image(systemName: "calendar")
                }

                Text("to")
                    .foregroundStyle(.tertiary)

                Label {
                    Text(assignment.endDate, style: .date)
                } icon: {
                    Image(systemName: "calendar.badge.checkmark")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func sessionsSection(_ assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Text("\(assignment.sessions.count) sessions")
                    .foregroundStyle(.secondary)
            }

            if assignment.sessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "clock",
                    description: Text("Add sessions to track your work")
                )
                .frame(height: 150)
            } else {
                SessionsTable(sessions: assignment.sessions, locations: locations)
            }
        }
    }

    @ViewBuilder
    private func financialSection(_ assignment: Assignment) -> some View {
        let earnings = EarningsAggregationService.totalEarnings(for: assignment)
        let subsidy = RuralSubsidyService.calculateSubsidy(for: assignment)

        VStack(alignment: .leading, spacing: 12) {
            Text("Financial Summary")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Total Earnings")
                        .foregroundStyle(.secondary)
                    Text(earnings, format: .currency(code: "AUD"))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }

                GridRow {
                    Text("Rural Subsidy (Est.)")
                        .foregroundStyle(.secondary)
                    Text(subsidy, format: .currency(code: "AUD"))
                        .foregroundStyle(.green)
                        .monospacedDigit()
                }

                Divider()

                GridRow {
                    Text("Total Value")
                        .fontWeight(.medium)
                    Text(earnings + subsidy, format: .currency(code: "AUD"))
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }
            .padding()
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SessionsTable: View {
    let sessions: [Session]
    let locations: [Location]

    var body: some View {
        Table(sessions) {
            TableColumn("Date") { session in
                Text(session.date, style: .date)
            }
            .width(100)

            TableColumn("Duration") { session in
                Text(formattedDuration(session))
            }
            .width(80)

            TableColumn("Type") { session in
                Text(session.sessionType.rawValue.capitalized)
            }
            .width(80)

            TableColumn("Earnings") { session in
                Text(session.earnings, format: .currency(code: "AUD"))
                    .monospacedDigit()
            }
            .width(90)
        }
        .frame(height: min(CGFloat(sessions.count) * 30 + 40, 300))
    }

    private func formattedDuration(_ session: Session) -> String {
        let hours = session.durationMinutes / 60
        let minutes = session.durationMinutes % 60
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }
}
```

### Step 4: Inspector Panel

**LocumTrackerMac/Inspectors/InspectorView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

struct InspectorView: View {
    @Bindable var navigationState: NavigationState
    @Query private var assignments: [Assignment]
    @Query private var locations: [Location]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch navigationState.selectedSection {
                case .assignments:
                    if let id = navigationState.selectedItemID,
                       let assignment = assignments.first(where: { $0.id == id }) {
                        AssignmentInspector(assignment: assignment, locations: locations)
                    } else {
                        AssignmentsSummaryInspector(assignments: assignments, locations: locations)
                    }

                case .locations:
                    if let id = navigationState.selectedItemID,
                       let location = locations.first(where: { $0.id == id }) {
                        LocationInspector(location: location)
                    } else {
                        LocationsSummaryInspector(locations: locations)
                    }

                case .fpsQuota:
                    FPSQuotaInspector(assignments: assignments)

                case .earnings:
                    EarningsInspector(assignments: assignments)

                default:
                    QuickActionsInspector(navigationState: navigationState)
                }
            }
            .padding()
        }
    }
}

struct AssignmentInspector: View {
    let assignment: Assignment
    let locations: [Location]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick Stats
            InspectorSection("Quick Stats") {
                StatRow(label: "Sessions", value: "\(assignment.sessions.count)")
                StatRow(label: "FPS Eligible",
                       value: "\(assignment.sessions.filter { $0.isFPSEligible }.count)")
                StatRow(label: "Days Remaining",
                       value: "\(daysRemaining)")
            }

            // Earnings Breakdown
            InspectorSection("Earnings") {
                let earnings = EarningsAggregationService.earningsByType(for: assignment)
                ForEach(Array(earnings.keys.sorted()), id: \.self) { type in
                    StatRow(label: type.capitalized,
                           value: earnings[type]!.formatted(.currency(code: "AUD")))
                }
            }

            // Quick Actions
            InspectorSection("Quick Actions") {
                Button("Add Session") {
                    // Add session action
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                Button("Generate Invoice") {
                    // Generate invoice action
                }
                .frame(maxWidth: .infinity)

                Button("View Location") {
                    // Navigate to location
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysRemaining: Int {
        let calendar = Calendar.current
        let today = Date()
        if today > assignment.endDate {
            return 0
        }
        return calendar.dateComponents([.day], from: today, to: assignment.endDate).day ?? 0
    }
}

struct AssignmentsSummaryInspector: View {
    let assignments: [Assignment]
    let locations: [Location]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InspectorSection("Overview") {
                StatRow(label: "Total Assignments", value: "\(assignments.count)")
                StatRow(label: "Active", value: "\(activeCount)")
                StatRow(label: "This Month", value: "\(thisMonthCount)")
            }

            InspectorSection("Total Earnings") {
                let total = assignments.reduce(Decimal.zero) { sum, assignment in
                    sum + EarningsAggregationService.totalEarnings(for: assignment)
                }
                Text(total, format: .currency(code: "AUD"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
    }

    private var activeCount: Int {
        assignments.filter { $0.status == .active }.count
    }

    private var thisMonthCount: Int {
        let calendar = Calendar.current
        let now = Date()
        return assignments.filter {
            calendar.isDate($0.startDate, equalTo: now, toGranularity: .month)
        }.count
    }
}

// MARK: - Shared Components

struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}
```

### Step 5: Location Views

**LocumTrackerMac/Views/Locations/LocationListView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

struct LocationListView: View {
    @Bindable var navigationState: NavigationState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Location.name) private var locations: [Location]

    @State private var showingAddSheet = false
    @State private var searchText = ""

    private var filteredLocations: [Location] {
        if searchText.isEmpty { return locations }
        return locations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Table(filteredLocations, selection: $navigationState.selectedItemID) {
            TableColumn("Name", value: \.name) { location in
                HStack {
                    MMMBadge(classification: location.mmmClassification)
                    Text(location.name)
                }
            }
            .width(min: 150, ideal: 200)

            TableColumn("Address") { location in
                Text(location.address ?? "—")
                    .foregroundStyle(.secondary)
            }
            .width(min: 150, ideal: 250)

            TableColumn("MMM") { location in
                Text("MMM \(location.mmmClassification)")
            }
            .width(60)

            TableColumn("Provider #") { location in
                Text(location.providerNumber ?? "—")
                    .font(.system(.body, design: .monospaced))
            }
            .width(100)
        }
        .searchable(text: $searchText, prompt: "Search locations...")
        .navigationTitle("Locations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("New Location", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddLocationSheet(isPresented: $showingAddSheet)
        }
    }
}
```

### Step 6: Receipt Views with Image Display

**LocumTrackerMac/Views/Receipts/ReceiptListView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

struct ReceiptListView: View {
    @Bindable var navigationState: NavigationState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]

    @State private var selectedCategory: ExpenseCategory?
    @State private var searchText = ""
    @State private var showingAddSheet = false

    private var filteredReceipts: [Receipt] {
        var result = receipts
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.merchant?.localizedCaseInsensitiveContains(searchText) ?? false ||
                $0.notes?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        return result
    }

    var body: some View {
        Table(filteredReceipts, selection: $navigationState.selectedItemID) {
            TableColumn("Date", value: \.date) { receipt in
                Text(receipt.date, style: .date)
            }
            .width(90)

            TableColumn("Merchant") { receipt in
                Text(receipt.merchant ?? "Unknown")
            }
            .width(min: 120, ideal: 180)

            TableColumn("Category") { receipt in
                CategoryBadge(category: receipt.category)
            }
            .width(100)

            TableColumn("Amount", value: \.date) { receipt in
                Text(receipt.amount, format: .currency(code: "AUD"))
                    .monospacedDigit()
            }
            .width(90)

            TableColumn("Deductible") { receipt in
                Image(systemName: receipt.isTaxDeductible ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(receipt.isTaxDeductible ? .green : .secondary)
            }
            .width(70)
        }
        .searchable(text: $searchText, prompt: "Search receipts...")
        .navigationTitle("Receipts")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Category", selection: $selectedCategory) {
                    Text("All Categories").tag(nil as ExpenseCategory?)
                    Divider()
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        Text(category.rawValue.capitalized).tag(category as ExpenseCategory?)
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("New Receipt", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddReceiptSheet(isPresented: $showingAddSheet)
        }
    }
}

struct CategoryBadge: View {
    let category: ExpenseCategory

    var body: some View {
        Label(category.rawValue.capitalized, systemImage: category.iconName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.2))
            .foregroundStyle(category.color)
            .clipShape(Capsule())
    }
}
```

### Step 7: FPS Quota View

**LocumTrackerMac/Views/FPSQuota/FPSQuotaView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI
import Charts

struct FPSQuotaView: View {
    @Bindable var navigationState: NavigationState
    @Query private var quotas: [QuarterlyQuota]
    @Query private var sessions: [Session]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                currentQuarterSection
                Divider()
                progressChartSection
                Divider()
                quarterHistorySection
            }
            .padding()
        }
        .navigationTitle("FPS Quota Tracking")
    }

    @ViewBuilder
    private var currentQuarterSection: some View {
        let currentQuarter = FPSQuarterService.currentQuarter()
        let eligibleSessions = sessions.filter {
            FPSQuarterService.isInQuarter($0.date, quarter: currentQuarter) && $0.isFPSEligible
        }

        VStack(alignment: .leading, spacing: 16) {
            Text("Current Quarter: \(currentQuarter.formatted)")
                .font(.headline)

            HStack(spacing: 40) {
                QuotaGauge(
                    title: "Sessions",
                    current: eligibleSessions.count,
                    required: 21,
                    maximum: 104
                )

                VStack(alignment: .leading, spacing: 8) {
                    StatRow(label: "Eligible Sessions", value: "\(eligibleSessions.count)")
                    StatRow(label: "Required for Active", value: "21")
                    StatRow(label: "Maximum Counted", value: "104")
                    StatRow(label: "Status",
                           value: eligibleSessions.count >= 21 ? "Active Quarter" : "In Progress")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var progressChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quarterly Progress")
                .font(.headline)

            Chart {
                ForEach(last8Quarters, id: \.self) { quarter in
                    let count = sessionsInQuarter(quarter)
                    BarMark(
                        x: .value("Quarter", quarter.shortFormatted),
                        y: .value("Sessions", count)
                    )
                    .foregroundStyle(count >= 21 ? .green : .orange)
                }

                RuleMark(y: .value("Required", 21))
                    .foregroundStyle(.red.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
            .frame(height: 200)
        }
    }

    @ViewBuilder
    private var quarterHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quarter History")
                .font(.headline)

            Table(quotas.sorted { $0.quarter > $1.quarter }) {
                TableColumn("Quarter") { quota in
                    Text(quota.quarter.formatted)
                }

                TableColumn("Sessions") { quota in
                    Text("\(quota.sessionCount)")
                        .monospacedDigit()
                }

                TableColumn("Status") { quota in
                    Text(quota.isActive ? "Active" : "Inactive")
                        .foregroundStyle(quota.isActive ? .green : .secondary)
                }

                TableColumn("Subsidy Est.") { quota in
                    Text(quota.estimatedSubsidy, format: .currency(code: "AUD"))
                        .monospacedDigit()
                }
            }
            .frame(height: 200)
        }
    }

    private var last8Quarters: [FPSQuarter] {
        FPSQuarterService.previousQuarters(count: 8)
    }

    private func sessionsInQuarter(_ quarter: FPSQuarter) -> Int {
        sessions.filter {
            FPSQuarterService.isInQuarter($0.date, quarter: quarter) && $0.isFPSEligible
        }.count
    }
}

struct QuotaGauge: View {
    let title: String
    let current: Int
    let required: Int
    let maximum: Int

    var body: some View {
        VStack {
            Gauge(value: Double(current), in: 0...Double(maximum)) {
                Text(title)
            } currentValueLabel: {
                Text("\(current)")
                    .font(.title)
                    .fontWeight(.bold)
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("\(maximum)")
            }
            .gaugeStyle(.accessoryCircular)
            .scaleEffect(1.5)

            Text(current >= required ? "Active" : "\(required - current) more needed")
                .font(.caption)
                .foregroundStyle(current >= required ? .green : .orange)
        }
        .frame(width: 120, height: 140)
    }
}
```

### Step 8: Earnings Dashboard

**LocumTrackerMac/Views/Earnings/EarningsView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI
import Charts

struct EarningsView: View {
    @Bindable var navigationState: NavigationState
    @Query private var assignments: [Assignment]

    @State private var selectedPeriod: EarningsPeriod = .thisMonth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                periodSelector
                summaryCards
                Divider()
                earningsChart
                Divider()
                earningsByAssignment
            }
            .padding()
        }
        .navigationTitle("Earnings")
    }

    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(EarningsPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 400)
    }

    private var summaryCards: some View {
        let filtered = filteredAssignments
        let totalEarnings = filtered.reduce(Decimal.zero) {
            $0 + EarningsAggregationService.totalEarnings(for: $1)
        }
        let totalSubsidy = filtered.reduce(Decimal.zero) {
            $0 + RuralSubsidyService.calculateSubsidy(for: $1)
        }

        return HStack(spacing: 20) {
            EarningsCard(
                title: "Total Earnings",
                amount: totalEarnings,
                icon: "dollarsign.circle.fill",
                color: .blue
            )

            EarningsCard(
                title: "Rural Subsidy",
                amount: totalSubsidy,
                icon: "leaf.fill",
                color: .green
            )

            EarningsCard(
                title: "Combined",
                amount: totalEarnings + totalSubsidy,
                icon: "chart.line.uptrend.xyaxis",
                color: .purple
            )
        }
    }

    @ViewBuilder
    private var earningsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Earnings Over Time")
                .font(.headline)

            Chart {
                ForEach(earningsByMonth, id: \.month) { data in
                    BarMark(
                        x: .value("Month", data.month, unit: .month),
                        y: .value("Earnings", data.earnings)
                    )
                    .foregroundStyle(.blue.gradient)
                }
            }
            .frame(height: 250)
        }
    }

    @ViewBuilder
    private var earningsByAssignment: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Assignment")
                .font(.headline)

            Table(filteredAssignments) {
                TableColumn("Assignment") { assignment in
                    Text(assignment.name ?? "Unnamed")
                }

                TableColumn("Sessions") { assignment in
                    Text("\(assignment.sessions.count)")
                        .monospacedDigit()
                }

                TableColumn("Earnings") { assignment in
                    Text(EarningsAggregationService.totalEarnings(for: assignment),
                         format: .currency(code: "AUD"))
                        .monospacedDigit()
                }

                TableColumn("Subsidy") { assignment in
                    Text(RuralSubsidyService.calculateSubsidy(for: assignment),
                         format: .currency(code: "AUD"))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
            }
            .frame(height: 200)
        }
    }

    private var filteredAssignments: [Assignment] {
        let (start, end) = selectedPeriod.dateRange
        return assignments.filter { assignment in
            assignment.startDate <= end && assignment.endDate >= start
        }
    }

    private var earningsByMonth: [(month: Date, earnings: Double)] {
        // Aggregate by month for chart
        var byMonth: [Date: Decimal] = [:]
        let calendar = Calendar.current

        for assignment in filteredAssignments {
            let monthStart = calendar.startOfMonth(for: assignment.startDate)
            let earnings = EarningsAggregationService.totalEarnings(for: assignment)
            byMonth[monthStart, default: 0] += earnings
        }

        return byMonth.map { (month: $0.key, earnings: NSDecimalNumber(decimal: $0.value).doubleValue) }
            .sorted { $0.month < $1.month }
    }
}

struct EarningsCard: View {
    let title: String
    let amount: Decimal
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(amount, format: .currency(code: "AUD"))
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

enum EarningsPeriod: String, CaseIterable {
    case thisMonth = "This Month"
    case thisQuarter = "This Quarter"
    case thisYear = "This Year"
    case allTime = "All Time"

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .thisMonth:
            let start = calendar.startOfMonth(for: now)
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        case .thisQuarter:
            let quarter = (calendar.component(.month, from: now) - 1) / 3
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarter * 3 + 1
            components.day = 1
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .month, value: 3, to: start)!
            return (start, end)
        case .thisYear:
            var components = calendar.dateComponents([.year], from: now)
            components.month = 1
            components.day = 1
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .year, value: 1, to: start)!
            return (start, end)
        case .allTime:
            return (Date.distantPast, Date.distantFuture)
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}
```

## Shared Components to Add to LocumTrackerUI

Create these in `Packages/LocumTrackerUI/Sources/LocumTrackerUI/`:

**Components/MMMBadge.swift**
```swift
import SwiftUI

public struct MMMBadge: View {
    public let classification: Int

    public init(classification: Int) {
        self.classification = classification
    }

    public var body: some View {
        Text("MMM\(classification)")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(MMMColors.color(for: classification).opacity(0.2))
            .foregroundStyle(MMMColors.color(for: classification))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
```

## Testing Phase 2

### Manual Testing Checklist

- [ ] Assignment list shows all assignments with sortable columns
- [ ] Clicking assignment shows detail view
- [ ] Inspector updates when selection changes
- [ ] Location list displays with MMM badges
- [ ] Receipt list filters by category
- [ ] FPS Quota shows current quarter progress
- [ ] Earnings dashboard calculates correctly
- [ ] Charts render properly
- [ ] Table sorting works
- [ ] Search filtering works
- [ ] Add sheets open and close properly

## Files Created/Modified

```
LocumTrackerMac/Views/
├── Assignments/
│   ├── AssignmentListView.swift      (updated from placeholder)
│   └── AssignmentDetailView.swift    (updated)
├── Locations/
│   ├── LocationListView.swift        (updated)
│   └── LocationDetailView.swift      (new)
├── Receipts/
│   ├── ReceiptListView.swift         (updated)
│   └── ReceiptDetailView.swift       (new)
├── FPSQuota/
│   └── FPSQuotaView.swift            (updated)
├── Earnings/
│   └── EarningsView.swift            (updated)
└── Reports/
    └── ReportsView.swift             (placeholder for Phase 4)

LocumTrackerMac/Inspectors/
└── InspectorView.swift               (updated with all inspectors)

Packages/LocumTrackerUI/
└── Components/
    └── MMMBadge.swift                (new shared component)
```

## Estimated Scope

- **Files modified**: ~15
- **New shared components**: 2-3
- **Lines of code**: ~1500-2000

## Next Phase

Proceed to [Phase 3: Advanced Features](03_advanced_features.md) for keyboard shortcuts, context menus, and multi-window support.
