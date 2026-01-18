# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LocumTracker is a work tracking application for Australian locum (deputy) doctors. It handles invoicing, receipt management, and rural subsidy compliance tracking under the Modified Monash Model (MMM) system.

**Current Status**: Core business logic package is complete and tested (29 passing tests). Storage and UI packages are scaffolded but minimal.

## Build and Test Commands

```bash
# Build packages
swift build --package-path Packages/LocumTrackerCore
swift build --package-path Packages/LocumTrackerStorage
swift build --package-path Packages/LocumTrackerUI

# Run all tests for LocumTrackerCore
swift test --package-path Packages/LocumTrackerCore

# Run a specific test
swift test --package-path Packages/LocumTrackerCore --filter RuralSubsidyServiceTests
```

## Architecture

### Package Structure

The codebase uses a modular Swift Package architecture:

- **LocumTrackerCore** (`Packages/LocumTrackerCore/`) - Pure business logic, complete and tested
  - `Models/` - SwiftData models: Assignment, Session, DailyRecord, Location, QuarterlyQuota, Receipt, LocumProfile
  - `Services/` - Pure calculation services: RuralSubsidyService, EarningsService, TaxService, ValidationService
  - `Utilities/` - Date extensions and helpers

- **LocumTrackerStorage** (`Packages/LocumTrackerStorage/`) - SwiftData schema configuration (scaffolded)

- **LocumTrackerUI** (`Packages/LocumTrackerUI/`) - Shared SwiftUI components (scaffolded)

### Platform Apps (Not Yet Created)

- iOS app with camera integration for receipt capture
- macOS app with advanced reporting

### Planned Features

- **LLM-powered receipt OCR**: Automatic extraction of merchant, amount, date, and category from receipt images
- **Android app**: Full feature parity with iOS
- **Cross-platform desktop**: Python/PySide6 implementation for Windows and Linux
- **Accounting exports**: Integration with MYOB, Xero, QuickBooks, and spreadsheet formats (CSV/Excel)

### Key Patterns

- **Pure functions**: All business logic in Core services uses pure functions without side effects
- **SwiftData models**: All persistent models use `@Model` macro
- **Testable services**: Services are static structs with no external dependencies

## Domain Concepts

### Rural Subsidy System (MMM)

Modified Monash Model classifications (1-7) determine subsidy eligibility:
- MMM1-2: Metropolitan/regional - not eligible
- MMM3-7: Rural/remote - eligible for hourly subsidies

Subsidy rates per hour (vocational):
- MMM3: $0, MMM4: $15, MMM5: $25, MMM6: $45, MMM7: $65
- Non-vocational: 80% of above rates
- Travel time credits: Only travel >1 hour counts toward subsidy

Quarterly quota: Minimum 21 sessions across MMM3-7 locations required for full subsidy payment. A session is 3-6 hours; typical 10-hour shifts count as 2 sessions.

### Rate Structures

- **Daily rate**: Fixed amount per day
- **Hourly rate**: Base hourly + optional on-call rate (25% default) + call-out rate (50% default)
- **Session types**: regular, on_call, call_out with different rate calculations

### Australian Tax

- GST rate: 10%
- ABN validation uses official 11-digit checksum algorithm (subtract 1 from first digit, multiply by weights [10,1,3,5,7,9,11,13,15,17,19], sum divisible by 89)
- Customer ABN required for invoices >= $82.50

## Code Standards

- All constants must be defined (no magic numbers)
- Public functions require doc strings with parameters and returns documented
- Unit tests mandatory for all business logic
- Use official Swift style guide (camelCase variables, PascalCase types)
- Models use SwiftData `@Model` macro
- Services are pure static structs
