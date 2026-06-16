#!/bin/bash

# LocumTracker Android Release Preparation Script
# This script prepares the app for release

set -e

echo "🚀 Preparing LocumTracker Android Release"
echo "=========================================="

# Check if we're in the Android directory
if [ ! -f "build.gradle.kts" ]; then
    echo "❌ Error: Please run this script from the Android directory"
    exit 1
fi

# Check for required environment variables
if [ -z "$KEYSTORE_PATH" ]; then
    echo "⚠️  Warning: KEYSTORE_PATH not set, using default"
    export KEYSTORE_PATH="release.keystore"
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
./gradlew clean

# Run tests
echo "🧪 Running tests..."
./gradlew testDebugUnitTest

# Run lint
echo "🔍 Running lint..."
./gradlew lint

# Build debug APK for testing
echo "📦 Building debug APK..."
./gradlew assembleDebug

# Build release APK
echo "📦 Building release APK..."
./gradlew assembleRelease

# Build release bundle
echo "📦 Building release bundle..."
./gradlew bundleRelease

# Generate release notes
echo "📝 Generating release notes..."
VERSION=$(grep "versionName" app/build.gradle.kts | cut -d'"' -f2)
DATE=$(date +%Y-%m-%d)

cat > "RELEASE_NOTES_${VERSION}.md" << EOF
# LocumTracker Android v${VERSION}

Released: ${DATE}

## What's New

### Features
- Full CRUD for assignments, locations, sessions, and receipts
- OCR receipt scanning with ML Kit
- Cloud sync with Firebase Firestore
- Data export (CSV/JSON)
- FPS quota tracking
- Earnings dashboard

### Improvements
- Performance optimizations
- Accessibility enhancements
- Better error handling

### Bug Fixes
- Fixed date formatting issues
- Fixed session duration calculations
- Fixed quota progress tracking

## Technical Details

- **Minimum SDK**: 26 (Android 8.0)
- **Target SDK**: 34 (Android 14)
- **Kotlin**: 1.9.20
- **Compose**: 1.5.5
- **Room**: 2.6.1
- **Firebase**: 32.7.0

## Testing

- 163 unit tests
- 39 database integration tests
- 14 UI tests
- 12 integration tests

## Download

- **APK**: [LocumTracker-v${VERSION}.apk](https://github.com/hherb/locumtracker/releases/download/v${VERSION}/LocumTracker-v${VERSION}.apk)
- **Bundle**: [LocumTracker-v${VERSION}.aab](https://github.com/hherb/locumtracker/releases/download/v${VERSION}/LocumTracker-v${VERSION}.aab)

## Installation

1. Download the APK or Bundle
2. Enable "Install from unknown sources" (for APK)
3. Install the app
4. Sign in with anonymous authentication
5. Start tracking your locum work!

## Support

- **Email**: support@locumtracker.com
- **GitHub**: https://github.com/hherb/locumtracker/issues
- **Documentation**: https://github.com/hherb/locumtracker/tree/main/Android

## License

This project is licensed under the GNU Affero General Public License v3.0.
EOF

echo "✅ Release preparation complete!"
echo ""
echo "📁 Artifacts:"
echo "   - app/build/outputs/apk/debug/*.apk (Debug)"
echo "   - app/build/outputs/apk/release/*.apk (Release)"
echo "   - app/build/outputs/bundle/release/*.aab (Bundle)"
echo "   - RELEASE_NOTES_${VERSION}.md"
echo ""
echo "📋 Next steps:"
echo "   1. Test the debug APK on real devices"
echo "   2. Review the release notes"
echo "   3. Create a GitHub release"
echo "   4. Upload to Google Play Console"
echo ""
echo "🎉 Good luck with your release!"
