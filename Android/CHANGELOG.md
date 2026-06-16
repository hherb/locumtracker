# Changelog

All notable changes to the LocumTracker Android app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-XX

### Added

#### Core Features
- Assignment management (CRUD)
- Location management with MMM classifications
- Session recording with time tracking
- Receipt management with camera capture
- FPS quota tracking with progress visualization
- Earnings dashboard with breakdowns

#### Advanced Features
- OCR receipt scanning (ML Kit)
- Cloud sync (Firebase Firestore)
- Data export (CSV/JSON)
- Profile management with ABN validation

#### UI/UX
- Material 3 design system
- Bottom navigation with 5 tabs
- Pull-to-refresh on lists
- Swipe-to-delete on items
- Date pickers for all date fields
- Form validation with error messages

#### Technical
- Room database with migrations
- Hilt dependency injection
- Kotlin coroutines and Flow
- Compose Navigation
- Unit tests (163 tests)
- Database integration tests
- UI tests

### Changed
- Migrated from XML layouts to Jetpack Compose
- Adopted Material 3 design system
- Improved error handling with Result types
- Enhanced accessibility support

### Fixed
- Date formatting consistency
- Currency display precision
- Session duration calculations
- Quota progress tracking

## [0.9.0] - 2024-01-XX (Beta)

### Added
- Beta release for testing
- Core CRUD operations
- Basic UI screens
- Room database

### Known Issues
- OCR accuracy varies with image quality
- Cloud sync may fail on slow connections
- Some edge cases in session calculations

## [0.8.0] - 2024-01-XX (Alpha)

### Added
- Initial alpha release
- Project setup
- Basic navigation
- Room database schema
- Core models

---

## Version History

- **1.0.0**: Production release
- **0.9.0**: Beta release
- **0.8.0**: Alpha release

## Upgrade Notes

### From 0.9.0 to 1.0.0
- No database migrations required
- Cloud sync data is compatible
- Export formats unchanged

### From 0.8.0 to 0.9.0
- Database schema updated
- Cloud sync requires re-authentication
- Export format updated (JSON structure)

## Support

For support, please contact:
- Email: support@locumtracker.com
- GitHub Issues: https://github.com/hherb/locumtracker/issues

## License

This project is licensed under the GNU Affero General Public License v3.0.
