# Developer Guide - LocumTracker

Welcome to the LocumTracker development guide. This document provides essential information for developers joining the project.

## Quick Start

### Prerequisites
- Xcode 15+
- iOS 16+, macOS 13+ deployment targets
- Apple Developer Account (for CloudKit)
- Git and GitHub access

### Setup Instructions
```bash
git clone https://github.com/hherb/locumtracker.git
cd locumtracker
git checkout develop
open LocumTracker.xcodeproj
```

## Project Structure

```
locumtracker/
├── Packages/
│   ├── LocumTrackerCore/       # Pure business logic
│   ├── LocumTrackerStorage/    # CloudKit integration
│   └── LocumTrackerUI/         # Shared UI components
├── LocumTrackeriOS/            # iOS app
├── LocumTrackermacOS/          # macOS app
└── Shared/                     # Shared resources
```

## Architecture Patterns

### MVVM + Clean Architecture
- **Presentation Layer**: SwiftUI views (platform-specific)
- **Domain Layer**: Pure business logic (shared packages)
- **Data Layer**: CloudKit repositories (shared packages)

### Pure Functions
All business logic is implemented as pure functions without side effects:
```swift
// ✅ Good - Pure function
public static func calculateEarnings(assignment: Assignment) -> EarningsBreakdown

// ❌ Bad - Side effects
public static func saveAndCalculate(_ assignment: Assignment) async throws -> EarningsBreakdown
```

## Core Concepts

### Rural Subsidy System
- **MMM Classifications**: Modified Monash Model (1-7)
- **Quarterly Quotas**: 40 hours across MMM3-7 locations
- **Rate Calculations**: Location and time-based subsidy amounts
- **Compliance**: Real-time quota tracking prevents forfeiture

### Rate Structures
- **Daily Rate**: Default for most assignments
- **Hourly Rate**: With optional on-call, call-out, special rates
- **Session Tracking**: 1-n sessions per day with precise times
- **Location Overrides**: Sessions can use different locations

## Data Models Overview

### Location
- MMM classification (1-7)
- Address, coordinates, effective dates
- ASGS RA classification (optional)

### Assignment
- Rate structure (daily/hourly)
- Base location and date ranges
- Optional special rates

### Session
- Start/end times with location
- MMM classification for subsidy calculation
- Travel time credits

### QuarterlyQuota
- MMM3-7 hours breakdown
- Progress tracking and warnings

## Development Workflow

### Branch Strategy
- `main`: Stable releases
- `develop`: Integration branch
- `feature/*`: Feature development

### Pull Request Process
1. Create feature branch from `develop`
2. Implement with tests
3. Ensure CI passes
4. Submit PR to `develop`
5. Code review required

### Testing Requirements
- Unit tests for all business logic
- Integration tests for CloudKit operations
- UI tests for critical user flows
- Test coverage > 90%

## Code Standards

### Swift Style Guide
- Use official Swift style guide
- camelCase for variables, PascalCase for types
- Descriptive names, no abbreviations
- Public APIs documented

### Documentation Requirements
```swift
/// Calculates rural subsidy based on session parameters
/// - Parameters:
///   - duration: Session duration in seconds
///   - mmmClassification: MMM classification (1-7)
///   - isVocational: Whether practitioner is vocational registered
/// - Returns: Subsidy calculation with breakdown
public static func calculateSessionSubsidy(
    duration: TimeInterval,
    mmmClassification: Int,
    isVocational: Bool
) -> SubsidyCalculation
```

### Constants
No magic numbers - all constants defined:
```swift
public enum SubsidyRates {
    public static let mmm4 = 15.00    // $15/hour
    public static let mmm5 = 25.00    // $25/hour
    public static let mmm6 = 45.00    // $45/hour
    public static let mmm7 = 65.00    // $65/hour
}
```

## CloudKit Integration

### Container Configuration
- Identifier: `iCloud.com.hherb.locumtracker`
- Sync: Automatic with SwiftData
- Offline: Local-first with conflict resolution

### Performance Considerations
- Use compound queries for efficiency
- Implement proper indexing
- Handle rate limiting gracefully
- Cache frequently accessed data

## Business Logic Examples


### Quarterly Progress
```swift
let progress = RuralSubsidyService.calculateQuarterlyProgress(
    sessions: quarterSessions,
    quarterDate: currentQuarter
)
// Returns: 32.5/40 hours, 81.25% progress
```

## Common Patterns

### Error Handling
```swift
enum LocumTrackerError: LocalizedError {
    case invalidMMMClassification
    case quotaExceeded
    case cloudSyncFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidMMMClassification:
            return "MMM classification must be between 1 and 7"
        // ...
        }
    }
}
```

### Repository Pattern
```swift
protocol AssignmentRepository {
    func save(_ assignment: Assignment) async throws
    func fetch(id: UUID) async throws -> Assignment?
    func fetch(in dateRange: ClosedRange<Date>) async throws -> [Assignment]
}
```

## Debugging Tips

### CloudKit Debugging
- Use CloudKit Dashboard for record inspection
- Enable CloudKit debug logging
- Test with development container
- Monitor sync status in debug builds

### Performance Profiling
- Use Instruments for memory profiling
- Monitor CloudKit API usage
- Test offline scenarios
- Profile sync performance

## Getting Help

### Documentation
- `doc/llm/`: LLM context and quick reference
- `doc/planning/`: Architecture decisions and plans
- Code comments and inline documentation

### Communication
- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: General questions
- Code Review: All PRs require review

### Common Issues
- CloudKit rate limiting: Implement retry logic
- Sync conflicts: Use merge strategies
- Performance: Optimize queries and caching
- Memory: Manage image data properly

## Development Resources

### Apple Documentation
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)

### Key Libraries
- SwiftData for local persistence
- CloudKit for cloud sync
- PDFKit for invoice generation
- AVFoundation for camera integration

## Testing Strategy

### Unit Tests
- Test all pure functions
- Edge cases for subsidy calculations
- MMM classification validation
- GST and ABN validation

### Integration Tests
- CloudKit synchronization
- Repository patterns
- Data model relationships
- Conflict resolution

### UI Tests
- Daily recording workflow
- Session management
- Quota tracking interface
- Export functionality

Remember: The primary goal is to simplify locum tracking while ensuring accurate rural subsidy compliance.