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
- [ ] Repository pattern for CRUD operations
- [ ] Query builders for common filters
- [ ] CloudKit sync status indicator

### Profile & Settings
- [x] LocumProfile setup/edit view
- [x] ABN validation in profile form
- [x] GST registration toggle
- [x] Default rate configuration

## Technical Debt

- [ ] Add unit tests for ViewModels (if introduced)
- [ ] Add UI tests for critical flows
- [ ] Accessibility audit (VoiceOver, Dynamic Type)
- [ ] Localization preparation
