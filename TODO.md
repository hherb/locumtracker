# LocumTracker - Next Implementation Steps

## Immediate (Xcode Setup Required)

- [x] Add local package dependencies in Xcode (File > Add Package Dependencies > Add Local)
  - `Packages/LocumTrackerCore`
  - `Packages/LocumTrackerStorage`
  - `Packages/LocumTrackerUI`
- [x] Enable iCloud capability in Signing & Capabilities
  - Check CloudKit
  - Add container: `iCloud.com.hherb.locumtracker`
- [x] Build and run to verify setup

## Phase 2: Core UI Features

### Assignment Management
- [x] Assignment detail view with edit capability
- [x] Delete confirmation dialog
- [x] Assignment status transitions (planned → active → completed)

### Session Recording
- [x] Session entry view (start/end time, session type)
- [x] Daily record view showing sessions for a day
- [x] ~~Quick session timer~~ (skipped - doctors record work retrospectively)

### Location Management
- [x] Location list view
- [x] Location detail/edit view
- [x] Location search/filter by MMM classification

## Phase 3: Business Features

### Earnings Dashboard
- [x] Summary view showing total earnings by period
- [x] Earnings breakdown by assignment/location
- [x] Export earnings report

### WIP FPS Tracking
- [x] Quarterly quota progress view (sessions-based)
- [x] MMM sessions breakdown by location
- [x] Active quarter tracker (multi-quarter history)

### Receipt Management
- [x] Receipt list view with categories
- [x] Camera integration for receipt capture (iOS)
- [x] Receipt detail view with image preview

## Phase 4: Data & Sync

### LocumTrackerStorage Package
- [x] Repository pattern for CRUD operations
- [x] Query builders for common filters
- [x] CloudKit sync status indicator

### Profile & Settings
- [x] LocumProfile setup/edit view
- [x] ABN validation in profile form
- [x] GST registration toggle
- [x] Default rate configuration

## Technical Debt

- [x] ~~Add unit tests for ViewModels~~ (N/A - app uses SwiftUI+SwiftData patterns without ViewModels)
- [x] Add UI tests for critical flows
  - Tab navigation tests
  - Earnings dashboard period selection
  - Receipts list and add sheet tests
  - FPS Quota view and Quarter History navigation
  - Profile settings form fields and ABN validation
- [x] Accessibility audit (VoiceOver, Dynamic Type)
  - Added accessibility labels to all badges (StatusBadge, MMMBadge, SessionTypeBadge, CategoryBadge)
  - Added accessibility to data visualization views (progress rings, earnings summaries)
  - Added accessibility identifiers to form fields for UI testing
  - Added @ScaledMetric for Dynamic Type support on progress indicators
  - Hidden decorative icons from VoiceOver
- [x] Localization preparation
  - Created Localizable.xcstrings String Catalog with 80+ UI strings
  - Strings organized with comments for translator context
  - Ready for translation to additional languages
