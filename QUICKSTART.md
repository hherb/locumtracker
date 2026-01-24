# LocumTracker Developer Quick Start

Get up and running with LocumTracker development in 5 minutes.

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| macOS | 14+ (Sonoma) | Required for Swift 5.9 toolchain |
| Xcode | 15+ | Download from Mac App Store |
| iOS Target | 17+ | Minimum deployment target |
| Apple Developer Account | Free or Paid | Required for device testing and CloudKit |

## 1. Clone and Build

```bash
# Clone the repository
git clone https://github.com/hherb/locumtracker.git
cd locumtracker

# Build all packages
swift build --package-path Packages/LocumTrackerCore
swift build --package-path Packages/LocumTrackerStorage
swift build --package-path Packages/LocumTrackerUI
```

## 2. Run Tests

```bash
# Run all Core tests (143 tests)
swift test --package-path Packages/LocumTrackerCore

# Run a specific test suite
swift test --package-path Packages/LocumTrackerCore --filter RuralSubsidyServiceTests
swift test --package-path Packages/LocumTrackerCore --filter EarningsServiceTests
swift test --package-path Packages/LocumTrackerCore --filter TaxServiceTests
```

## 3. Open in Xcode

```bash
# Open the iOS app project
open LocumTracker/LocumTracker.xcodeproj
```

Select the `LocumTracker` scheme and run on a simulator (iPhone 15 Pro recommended).

## Project Structure

```
locumtracker/
├── Packages/                      # Swift Package modules
│   ├── LocumTrackerCore/          # Business logic (complete, 143 tests)
│   │   ├── Models/                # SwiftData models
│   │   │   ├── Assignment.swift   # Work contracts with rates
│   │   │   ├── Session.swift      # Individual work sessions
│   │   │   ├── Location.swift     # Locations with MMM classification
│   │   │   ├── Receipt.swift      # Expense receipts
│   │   │   └── QuarterlyQuota.swift # Rural subsidy tracking
│   │   ├── Services/              # Pure calculation services
│   │   │   ├── RuralSubsidyService.swift    # MMM/FPS calculations
│   │   │   ├── EarningsService.swift        # Income calculations
│   │   │   ├── TaxService.swift             # GST/ABN validation
│   │   │   └── FPSQuarterService.swift      # Quarter eligibility
│   │   └── Utilities/             # Date helpers
│   │
│   ├── LocumTrackerStorage/       # SwiftData + CloudKit
│   ├── LocumTrackerOCR/           # Receipt OCR (PaddleOCR)
│   └── LocumTrackerUI/            # Shared SwiftUI components
│
├── LocumTracker/                  # iOS app
│   ├── LocumTracker/              # App source code
│   ├── LocumTrackerTests/         # Unit tests
│   └── LocumTrackerUITests/       # UI tests
│
├── doc/                           # Documentation
│   ├── developers/                # Developer guides
│   ├── llm/                       # Domain reference (for AI/LLM context)
│   └── planning/                  # Architecture decisions
│
└── scripts/                       # Build utilities
    └── prepare_ocr_models.py      # OCR model preparation
```

## Key Domain Concepts

### Modified Monash Model (MMM)

The app tracks rural incentive payments under Australia's WIP Doctor Stream FPS:

| MMM Level | Area Type | Eligible for Subsidy |
|-----------|-----------|---------------------|
| MMM 1-2 | Metropolitan | No |
| MMM 3-7 | Rural/Remote | Yes |

### Session Requirements

- Minimum **3 continuous hours** = 1 valid session
- Maximum **2 sessions per day** counted
- Need **21 sessions per quarter** for an "active quarter"
- Maximum 104 sessions counted per quarter

### Rate Structures

```swift
// Daily rate - fixed amount per day
assignment.rateType = .daily
assignment.dailyRate = 2500.00

// Hourly rate - with optional on-call/call-out multipliers
assignment.rateType = .hourly
assignment.hourlyRate = 200.00
assignment.onCallRate = 50.00   // Default: 25% of hourly
assignment.callOutRate = 100.00 // Default: 50% of hourly
```

## Making Your First Change

### 1. Create a feature branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Follow the code standards

- **Pure functions** for all business logic (no side effects)
- **No magic numbers** - use named constants
- **Document public APIs** with doc comments
- **Write tests** for all business logic

Example service pattern:
```swift
public struct MyService {
    /// Calculates something useful
    /// - Parameter input: The input value
    /// - Returns: The calculated result
    public static func calculate(input: Double) -> Double {
        return input * Constants.multiplier
    }
}
```

### 3. Run tests before committing

```bash
swift test --package-path Packages/LocumTrackerCore
```

### 4. Submit a pull request

- Target the `develop` branch
- Include a clear description
- Ensure CI passes

## Common Development Tasks

### Add a new model

1. Create the model in `Packages/LocumTrackerCore/Sources/LocumTrackerCore/Models/`
2. Use the `@Model` macro for SwiftData
3. Export in `LocumTrackerCore.swift`

### Add a new service

1. Create a static struct in `Services/`
2. Implement pure functions only
3. Add tests in `Tests/LocumTrackerCoreTests/`
4. Export in `LocumTrackerCore.swift`

### Test a calculation

```swift
import XCTest
@testable import LocumTrackerCore

final class MyServiceTests: XCTestCase {
    func testCalculation() {
        let result = MyService.calculate(input: 100)
        XCTAssertEqual(result, expectedValue)
    }
}
```

## Useful Commands

```bash
# Build all packages
swift build --package-path Packages/LocumTrackerCore

# Run tests with verbose output
swift test --package-path Packages/LocumTrackerCore -v

# Clean build
swift package --package-path Packages/LocumTrackerCore clean

# Update dependencies
swift package --package-path Packages/LocumTrackerCore update
```

## Getting Help

- **Code guidelines**: See [CLAUDE.md](CLAUDE.md) for detailed standards
- **Developer docs**: See [doc/developers/README.md](doc/developers/README.md)
- **Domain rules**: See [doc/llm/wip_doctor_stream_fps_rules.md](doc/llm/wip_doctor_stream_fps_rules.md)
- **Issues**: [GitHub Issues](https://github.com/hherb/locumtracker/issues)
- **Questions**: [GitHub Discussions](https://github.com/hherb/locumtracker/discussions)

## Next Steps

1. Read through the models in `Packages/LocumTrackerCore/Sources/LocumTrackerCore/Models/`
2. Review the test files to understand expected behavior
3. Run the iOS app in the simulator to see the UI
4. Pick an issue from GitHub and start contributing
