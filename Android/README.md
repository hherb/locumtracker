# LocumTracker Android App

Work tracking application for Australian locum (deputy) doctors. Built with Kotlin, Jetpack Compose, and Room database.

## Features

### Core Features
- **Assignment Management**: Create, edit, and track work assignments
- **Location Management**: Track multiple work locations with MMM classifications
- **Session Recording**: Log work sessions with time tracking
- **Receipt Management**: Capture and categorize expense receipts
- **FPS Quota Tracking**: Monitor quarterly session requirements
- **Earnings Dashboard**: Track earnings by location and period

### Advanced Features
- **OCR Receipt Scanning**: ML Kit-powered receipt text extraction
- **Cloud Sync**: Firebase Firestore backup and restore
- **Data Export**: CSV and JSON export capabilities
- **Camera Integration**: Capture receipt images directly

## Architecture

### Tech Stack
- **UI**: Jetpack Compose with Material 3
- **Navigation**: Compose Navigation
- **Database**: Room (SQLite)
- **Dependency Injection**: Hilt
- **Cloud**: Firebase Firestore
- **OCR**: Google ML Kit
- **Async**: Kotlin Coroutines + Flow

### Project Structure
```
Android/
├── app/                          # Android app module
│   ├── src/main/
│   │   ├── java/com/hherb/locumtracker/
│   │   │   ├── data/
│   │   │   │   ├── database/     # Room database, DAOs, entities
│   │   │   │   ├── repository/   # Data repositories
│   │   │   │   ├── sync/         # Firebase sync
│   │   │   │   ├── ocr/          # ML Kit OCR
│   │   │   │   ├── export/       # CSV/JSON export
│   │   │   │   └── cache/        # Local caching
│   │   │   ├── ui/
│   │   │   │   ├── screens/      # Compose screens
│   │   │   │   ├── navigation/   # Navigation graph
│   │   │   │   ├── theme/        # Material 3 theme
│   │   │   │   ├── components/   # Reusable components
│   │   │   │   └── accessibility/ # Accessibility helpers
│   │   │   ├── di/               # Hilt modules
│   │   │   └── util/             # Utility classes
│   │   └── res/                  # Resources
│   └── build.gradle.kts
├── core/                         # KMP shared module
│   ├── src/commonMain/           # Shared code
│   └── build.gradle.kts
└── build.gradle.kts
```

## Setup

### Prerequisites
- Android Studio Hedgehog (2023.1.1) or later
- **JDK 17 — a standard distribution (e.g. Temurin 17), _not_ Android Studio's bundled JetBrains Runtime (JBR).**
  AGP 8.2's `JdkImageTransform` runs `jlink`, which fails on the JBR (`core-for-system-modules.jar` transform error).
  Point `JAVA_HOME` at a real JDK 17 for command-line builds.
- Android SDK 34 (auto-provisioned by AGP if SDK licenses are accepted)

### Installation (Android Studio)
1. Clone the repository
2. Open the `Android/` folder in Android Studio
3. Sync Gradle
4. Replace the placeholder `app/google-services.json` with your real Firebase config (see below)
5. Build and run

### Building from the Command Line
```bash
cd Android
export JAVA_HOME=/path/to/jdk-17        # must be a standard JDK 17, not the JBR
./gradlew :app:assembleDebug            # outputs APKs under app/build/outputs/apk/debug/
```
The Gradle wrapper is pinned to Gradle 8.5 (required — Gradle 9.x cannot configure the
Kotlin 1.9.20 build). `local.properties` (SDK path) is created automatically by Android
Studio, or add `sdk.dir=/path/to/Android/sdk` manually for CLI builds.

### Firebase Setup
A **placeholder** `app/google-services.json` (dummy credentials) is committed so the build
configures out of the box. Replace it with your real config before shipping, and keep the
real file out of version control:
1. Create a Firebase project
2. Add an Android app with package name `com.hherb.locumtracker`
3. Download `google-services.json` and replace the placeholder in `app/`
4. Enable Firestore in the Firebase Console

## Testing

### Run Unit Tests
```bash
./gradlew :core:testDebugUnitTest
```

### Run Instrumented Tests
Instrumented tests (UI/DAO) require a connected device or running emulator:
```bash
./gradlew :app:connectedDebugAndroidTest
```

### Test Coverage
- **Core unit tests: 104 passing** (`:core:testDebugUnitTest`) — models + business-logic
  services (rural subsidy, earnings, tax, FPS quarter).
- Instrumented UI/DAO tests live under `app/src/androidTest/` and run on a device/emulator.

## Key Classes

### Data Layer
- `LocumTrackerDatabase`: Room database with all entities
- `LocationRepository`: Location CRUD operations
- `AssignmentRepository`: Assignment CRUD operations
- `SessionRepository`: Session and DailyRecord operations
- `ReceiptRepository`: Receipt and Attachment operations
- `ProfileRepository`: Profile and Quota operations

### Sync Layer
- `FirebaseSyncService`: Firebase Firestore operations
- `SyncManager`: Coordinates local and remote data
- `CacheManager`: Local preference caching

### UI Layer
- `AssignmentsScreen`: Assignment list with cards
- `AssignmentDetailScreen`: Full assignment info
- `AddAssignmentScreen`: Create new assignment
- `EditAssignmentScreen`: Edit existing assignment
- `SessionListScreen`: Sessions grouped by day
- `AddSessionScreen`: Create new session
- `ReceiptsScreen`: Receipt list with totals
- `ReceiptDetailScreen`: Full receipt info
- `AddReceiptScreen`: Create receipt with OCR
- `EditReceiptScreen`: Edit existing receipt
- `QuotaScreen`: FPS quota progress
- `EarningsScreen`: Earnings dashboard
- `SettingsScreen`: Profile and settings

## Performance Optimizations

### Database
- WAL mode for concurrent access
- Indexed columns for fast queries
- Connection pooling
- Batch operations

### UI
- LazyColumn for efficient lists
- State hoisting
- Memoization of expensive calculations
- Image caching

### Memory
- Flow-based data loading
- Coroutine scope management
- Bitmap recycling

## Accessibility

### Features
- Content descriptions for all interactive elements
- Semantic properties for screen readers
- Dynamic type support
- High contrast mode support
- Keyboard navigation

### Labels
- Assignment status and details
- Location and MMM classification
- Session type and duration
- Receipt amount and category
- Quota progress

## Export Formats

### CSV
- Receipts with date, category, amount
- Sessions with time and duration
- Summary statistics

### JSON
- Structured data format
- Nested objects for relationships
- ISO 8601 timestamps

## Cloud Sync

### Features
- Two-way sync with Firebase
- Offline-first architecture
- Conflict resolution
- Automatic backup reminders

### Data Synced
- Locations
- Assignments
- Sessions and Daily Records
- Receipts
- Profile
- Quotas

## Known Limitations

1. **Offline Support**: Limited offline editing capabilities
2. **Image Storage**: Large images may consume significant storage
3. **Sync Conflicts**: Basic conflict resolution (last-write-wins)
4. **OCR Accuracy**: Dependent on image quality

## Future Enhancements

1. **Offline-First**: Full offline editing with sync queue
2. **Widgets**: Quick session logging widget
3. **Notifications**: Session reminders
4. **Biometrics**: App lock with fingerprint
5. **Dark Mode**: System-level dark mode support

## License

This project is licensed under the GNU Affero General Public License v3.0 - see the [LICENSE](../LICENSE) file for details.
