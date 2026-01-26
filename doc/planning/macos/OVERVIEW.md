# macOS App Implementation Plan: Overview

*Implementation planning document for LocumTracker macOS*

This guide details the phased approach to building the LocumTracker macOS app, leveraging the extended screen real estate for enhanced UX while maximizing code reuse with the iOS app.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LocumTracker macOS                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Sidebar    │  │   Content    │  │   Inspector  │  │  Reporting   │    │
│  │  Navigation  │  │    Area      │  │    Panel     │  │   Windows    │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
├─────────────────────────────────────────────────────────────────────────────┤
│                              macOS-Specific Layer                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Keyboard Shortcuts │ Context Menus │ Drag-Drop │ Multi-Window │ Print │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────────────────┤
│                              Shared Packages                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │LocumTrackerCore │  │LocumTrackerUI   │  │LocumTrackerOCR  │             │
│  │ (Business Logic)│  │ (Shared Views)  │  │ (Receipt OCR)   │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│  ┌───────────────────┐  ┌─────────────────────────────────────────┐        │
│  │LocumTrackerStorage│  │ LocumTrackerReporting (NEW - Phase 4)   │        │
│  │ (Persistence)     │  │ (Export Services, Report Generation)    │        │
│  └───────────────────┘  └─────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Current State

### Existing Cross-Platform Foundation

| Package | Status | macOS Support |
|---------|--------|---------------|
| LocumTrackerCore | Complete (43 tests) | macOS 14+ |
| LocumTrackerStorage | Production-ready | macOS 14+ |
| LocumTrackerUI | Growing | macOS 14+ |
| LocumTrackerOCR | Production-ready | macOS 12+ |

### Existing macOS Scaffolding

The codebase already has macOS hooks:
- `ContentView.swift` uses `NavigationSplitView` (macOS-ready)
- `LocumTrackerApp.swift` has `#if os(macOS)` conditionals
- Settings window placeholder exists
- All SwiftData models work on both platforms

## Design Principles

### 1. Extended Screen Real Estate UX

**Three-Column Layout (Primary Pattern)**
```
┌─────────────────────────────────────────────────────────────────────┐
│  Sidebar (220pt)  │   Content (flexible)    │   Inspector (280pt)   │
├───────────────────┼─────────────────────────┼───────────────────────┤
│  Assignments      │   Assignment Details    │   Quick Stats         │
│  • Active ▼       │   ┌─────────────────┐   │   ┌─────────────────┐ │
│    └ Darwin RDH   │   │  Sessions List  │   │   │ Total Earnings  │ │
│    └ Alice GP     │   │  - June 1: 8hrs │   │   │ $12,450.00      │ │
│  • Completed ▼    │   │  - June 2: 10hr │   │   │                 │ │
│  ─────────────    │   │  - June 3: 8hrs │   │   │ FPS Sessions    │ │
│  Locations        │   └─────────────────┘   │   │ 18/21 required  │ │
│  Receipts         │   ┌─────────────────┐   │   └─────────────────┘ │
│  FPS Quota        │   │  Actions        │   │   ┌─────────────────┐ │
│  Earnings         │   │  [Add Session]  │   │   │ Quick Actions   │ │
│  ─────────────    │   │  [Edit]         │   │   │ [+ Session]     │ │
│  Reports          │   └─────────────────┘   │   │ [Generate Inv]  │ │
│  Settings         │                         │   └─────────────────┘ │
└───────────────────┴─────────────────────────┴───────────────────────┘
```

**Benefits over iOS Tab View:**
- All sections visible simultaneously in sidebar
- Inspector panel shows context-sensitive information
- Direct drill-down without navigation stack
- Multiple windows for parallel workflows

### 2. macOS-Specific Features

| Feature | Description | Priority |
|---------|-------------|----------|
| **Multiple Windows** | Open assignments/reports in separate windows | High |
| **Keyboard Shortcuts** | Cmd+N, Cmd+S, arrow navigation, etc. | High |
| **Context Menus** | Right-click on any item for quick actions | High |
| **Drag & Drop** | Drop receipt images, reorder sessions | Medium |
| **Menu Bar** | Standard macOS menus with all actions | High |
| **Touch Bar** | Quick actions (legacy Macs) | Low |
| **Print Support** | Professional invoice/report printing | High |
| **Quick Look** | Space bar preview for receipts | Medium |

### 3. Code Sharing Strategy

**Fully Shared (Use Directly)**
- All SwiftData models
- All Core services (pure functions)
- All repositories
- CloudKit sync
- Currency formatting, colors, constants

**Adapted for macOS (Same Logic, Different Presentation)**
- List views → Table views with sortable columns
- Sheets → Popovers or inline editing
- Tab bar → Sidebar navigation
- Pull-to-refresh → Menu/toolbar refresh

**macOS-Only (New Code)**
- Multi-window management
- Menu bar actions
- Keyboard navigation system
- Inspector panels
- Advanced reporting views
- Print/export formatting

## Package Evolution

### New Package: LocumTrackerReporting

A new pure-function package for advanced reporting capabilities:

```swift
// Packages/LocumTrackerReporting/
Sources/
├── ExportServices/
│   ├── CSVExportService.swift      // CSV generation
│   ├── ExcelExportService.swift    // Excel/XLSX generation
│   └── PDFExportService.swift      // PDF invoice/report generation
├── ReportGenerators/
│   ├── EarningsReportGenerator.swift
│   ├── FPSComplianceReportGenerator.swift
│   ├── TaxSummaryReportGenerator.swift
│   └── ExpenseReportGenerator.swift
├── Models/
│   ├── ReportConfiguration.swift
│   ├── ExportFormat.swift
│   └── ReportPeriod.swift
└── Formatters/
    ├── InvoiceFormatter.swift
    └── StatementFormatter.swift
```

**Why a Separate Package?**
- Pure functions with no UI dependencies
- Reusable on iOS (future enhanced export)
- Testable in isolation
- Potentially usable by Android/desktop versions

### LocumTrackerUI Expansion

Shared components that work on both platforms:

```swift
// Additional shared components
├── Tables/
│   ├── SessionTableRow.swift       // Configurable row for table/list
│   └── ReceiptTableRow.swift
├── Charts/
│   ├── EarningsChart.swift         // SwiftUI Charts
│   └── FPSProgressChart.swift
├── Inspectors/
│   ├── AssignmentInspector.swift   // Right panel content
│   └── LocationInspector.swift
```

## Implementation Phases

| Phase | Document | Focus | Context Window Fit |
|-------|----------|-------|-------------------|
| 1 | [01_foundation.md](01_foundation.md) | macOS target setup, basic navigation | Small - config/setup |
| 2 | [02_core_views.md](02_core_views.md) | Sidebar, content views, inspector | Medium - view code |
| 3 | [03_advanced_features.md](03_advanced_features.md) | Keyboard, menus, multi-window | Medium - interaction code |
| 4 | [04_reporting_export.md](04_reporting_export.md) | Reporting package, export, print | Medium - new package |
| 5 | [05_polish_integration.md](05_polish_integration.md) | Polish, preferences, final touches | Small - refinements |

### Phase Sizing for Context Windows

Each phase is designed to fit within a single Claude Code session:
- **Small phases** (~50-100 files touched): Setup, configuration, polish
- **Medium phases** (~20-40 files touched): Feature implementation
- Each phase produces a working, testable increment

## File Structure (Final State)

```
locumtracker/
├── Packages/
│   ├── LocumTrackerCore/          # Unchanged - pure business logic
│   ├── LocumTrackerStorage/       # Unchanged - persistence
│   ├── LocumTrackerUI/            # Expanded - shared components
│   ├── LocumTrackerOCR/           # Unchanged - OCR engine
│   └── LocumTrackerReporting/     # NEW - export and reporting
│
├── LocumTracker/                  # iOS app (existing)
│   ├── LocumTracker/
│   ├── LocumTrackerShare/
│   └── ...
│
└── LocumTrackerMac/               # NEW - macOS app
    ├── LocumTrackerMac.xcodeproj
    └── LocumTrackerMac/
        ├── App/
        │   ├── LocumTrackerMacApp.swift
        │   └── AppCommands.swift
        ├── Navigation/
        │   ├── SidebarView.swift
        │   └── NavigationState.swift
        ├── Views/
        │   ├── Assignments/
        │   ├── Sessions/
        │   ├── Locations/
        │   ├── Receipts/
        │   ├── FPSQuota/
        │   ├── Earnings/
        │   └── Reports/
        ├── Inspectors/
        │   ├── AssignmentInspectorView.swift
        │   └── ...
        ├── Windows/
        │   ├── ReportWindow.swift
        │   └── InvoiceWindow.swift
        ├── Settings/
        │   └── SettingsView.swift
        └── Resources/
            └── Assets.xcassets
```

## Success Criteria

### Phase 1 Complete
- [ ] macOS app builds and runs
- [ ] Basic sidebar navigation works
- [ ] Data loads from shared CloudKit container

### Phase 2 Complete
- [ ] All iOS views adapted for macOS
- [ ] Three-column layout functional
- [ ] Inspector panels showing context

### Phase 3 Complete
- [ ] All keyboard shortcuts working
- [ ] Context menus on all items
- [ ] Multiple windows supported

### Phase 4 Complete
- [ ] LocumTrackerReporting package complete
- [ ] CSV/Excel export working
- [ ] PDF invoice generation
- [ ] Print support functional

### Phase 5 Complete
- [ ] Full menu bar integration
- [ ] Settings window complete
- [ ] Performance optimized
- [ ] Ready for TestFlight

## Risk Considerations

| Risk | Mitigation |
|------|------------|
| SwiftData macOS quirks | Test early in Phase 1 |
| CloudKit sync issues | Same container as iOS, test sync |
| UI adaptation complexity | Maximize shared components |
| Reporting library size | Consider lazy loading |
| Print formatting | Use PDFKit with templates |

## Next Steps

Proceed to [Phase 1: Foundation](01_foundation.md) to begin implementation.
