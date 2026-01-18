# LocumTracker

A comprehensive work tracking application for locum (deputy) doctors with short-term contracts, featuring rural subsidy compliance, cloud synchronization, and cross-platform support.

## Purpose

LocumTracker is designed to solve two critical problems for medical practitioners:

1. **Primary Purpose**: Invoicing and receipt management for locum work
2. **Critical Feature**: Rural subsidy compliance for Australian healthcare system

## Key Features

### Assignment Tracking
- **Flexible Rate Structures**: Fixed daily rates (majority) or hourly rates
- **Session-Based Recording**: 1-n sessions per day with precise start/end times
- **Location Management**: MMM 1-7 classifications for rural subsidy eligibility
- **Rate Variations**: Support for on-call, call-out, and special rates (holidays, weekends)

### Rural Subsidy Compliance
- **MMM Classification Tracking**: Modified Monash Model (MMM1-MMM7) for locations
- **Quarterly Quota Monitoring**: min 21 sessions across MMM3-7 locations
- **Real-Time Progress**: Daily quota status to prevent forfeiture
- **Subsidy Calculations**: Vocational vs non-vocational rate variations
- **Travel Time Credits**: Automatic subsidy calculation for long travel times

### Receipt Management
- **Image Capture**: Camera integration (iOS) and file upload (macOS)
- **Cloud Storage**: Automatic synchronization via CloudKit
- **Categorization**: Travel, accommodation, meals, and other expenses
- **Daily Linking**: Connect receipts to specific work sessions

### Invoice Generation
- **Australian Focus**: ABN validation and GST calculations
- **Flexible Templates**: Support for multiple countries and tax systems
- **Export Formats**: PDF for billing, JSON for accounting software
- **Compliance Ready**: Tax invoice requirements met for B2B transactions

## Architecture

### Technology Stack
- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Local persistence with CloudKit integration
- **CloudKit**: Cloud synchronization and storage
- **Swift Package Manager**: Modular shared code architecture

### Package Structure
```
Packages/
├── LocumTrackerCore/           # Pure business logic, models, validation
├── LocumTrackerStorage/        # CloudKit integration and repositories
└── LocumTrackerUI/             # Shared SwiftUI components
```

### Cross-Platform Support
- **iOS**: Mobile app with camera integration, quick daily entry
- **macOS**: Desktop app with advanced reporting and CSV import
- **Shared Business Logic**: Common code across both platforms

### Data Models
- **Assignment**: Work contracts with rate structures and date ranges
- **Location**: Workplace details with MMM classification
- **DailyRecord**: Container for multiple sessions per day
- **Session**: Individual work periods with times and subsidies
- **QuarterlyQuota**: Rural subsidy compliance tracking
- **Receipt**: Expense management with image attachments
- **LocumProfile**: User settings and professional details

## Rural Subsidy System

### Modified Monash Model (MMM)
- **MMM1**: Major cities 
- **MMM2**: Regional cities 
- **MMM3**: Large rural towns
- **MMM4**: Medium rural towns 
- **MMM5**: Small rural towns
- **MMM6**: Remote communities
- **MMM7**: Very remote communities

### Subsidy Calculations
- **Base Rates**: 
- **Vocational Bonus**: 
- **Travel Credits**: 
- **Quarterly Quota**:

### Example Locations
- **Cooktown QLD 4895**: MMM6 classification
- **Dorrigo NSW 2453**: MMM5 classification

## Development

### Prerequisites
- **Xcode 15+**: Latest iOS/macOS development tools
- **iOS 16+**: Minimum supported iOS version
- **macOS 13+**: Minimum supported macOS version
- **Apple Developer Account**: For CloudKit container setup
- **Git**: Version control and collaboration

### Project Setup
```bash
# Clone repository
git clone https://github.com/hherb/locumtracker.git
cd locumtracker

# Switch to develop branch
git checkout develop

# Open in Xcode
open LocumTracker.xcodeproj
```

### CloudKit Setup
1. Create Apple Developer account and enable CloudKit
2. Configure container: `iCloud.com.hherb.locumtracker`
3. Set up record types for all data models
4. Configure indexes and security roles
5. Update entitlements in Xcode project

### Build and Test
```bash
# Build all packages
xcodebuild -scheme LocumTracker-Core build
xcodebuild -scheme LocumTracker-Storage build
xcodebuild -scheme LocumTracker-UI build

# Run tests
swift test --package-path Packages/LocumTrackerCore
swift test --package-path Packages/LocumTrackerStorage
swift test --package-path Packages/LocumTrackerUI
```

## Documentation

### Documentation Structure
```
doc/
├── llm/                  # LLM context and development information
├── user/                 # User manual and quick start guide
├── developers/            # Developer onboarding and code understanding
└── planning/             # Architecture decisions and planning documents
```

### Key Documents
- **Architecture Overview**: Detailed technical architecture
- **Data Models**: Complete data model documentation
- **Rural Subsidy Guide**: MMM classification and compliance
- **API Documentation**: Public interfaces and usage examples
- **Contributing Guidelines**: Development workflow and standards

## Contributing

### Golden Rules
- **Pure Functions**: Prefer pure, reusable functions over complex constructs
- **No Magic Numbers**: All constants must be defined and documented
- **Documentation**: All public functions must have doc strings
- **Testing**: Unit tests mandatory for all business logic

### Development Workflow
1. Create feature branch from `develop`
2. Implement changes with tests
3. Ensure all tests pass
4. Create pull request to `develop`
5. Review and merge
6. Periodic releases to `main`

### Code Standards
- **Swift Style**: Follow official Swift style guide
- **Naming**: Use descriptive, camelCase for variables, PascalCase for types
- **Comments**: Document complex logic and business rules
- **Error Handling**: Use proper error types and propagation

## License

This project is licensed under the **AGPL v3 License**. See [LICENSE](LICENSE) file for details.

## Support

### Issues and Feature Requests
- **Bug Reports**: Create GitHub issue with detailed description
- **Feature Requests**: Create GitHub issue with use case description
- **Questions**: Use GitHub discussions for general questions

### Contact
- **Maintainer**: hherb
- **Repository**: https://github.com/hherb/locumtracker
- **Documentation**: See `doc/` directory for comprehensive guides

## Roadmap

### Phase 1: Foundation (Current)
- [x] Project structure and shared packages
- [x] Core data models and business logic
- [x] CloudKit integration and storage layer
- [x] Comprehensive test suite
- [x] Documentation and developer setup

### Phase 2: iOS App
- [ ] SwiftUI interface for mobile users
- [ ] Camera integration and receipt capture
- [ ] Quick daily entry workflow
- [ ] Real-time quota tracking
- [ ] Calendar integration

### Phase 3: macOS App
- [ ] Desktop interface for advanced users
- [ ] Bulk operations and CSV import
- [ ] Advanced reporting and analytics
- [ ] Multi-window support
- [ ] Keyboard shortcuts

### Phase 4: Integration & Polish
- [ ] Cross-platform sync optimization
- [ ] Invoice generation system
- [ ] PDF and JSON export
- [ ] User documentation
- [ ] App Store preparation

## Acknowledgments

This project addresses real-world challenges faced by medical practitioners working in rural and remote areas. The rural subsidy compliance features are particularly important for healthcare accessibility in Australia.

Special thanks to the medical community for providing detailed requirements and feedback throughout the development process.
