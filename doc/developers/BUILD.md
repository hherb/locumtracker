# Build Guide - LocumTracker

This document covers building the LocumTracker project, including the iOS app and all Swift packages.

## Prerequisites

- **Xcode 15+** (16 recommended)
- **iOS 16+** deployment target
- **macOS 13+** (Ventura or later)
- **Apple Developer Account** (for CloudKit and device testing)
- **Git** for version control

## Project Structure

```
locumtracker/
├── LocumTracker/                    # iOS app (Xcode project)
│   └── LocumTracker.xcodeproj
├── Packages/
│   ├── LocumTrackerCore/            # Pure business logic
│   ├── LocumTrackerStorage/         # SwiftData repositories
│   ├── LocumTrackerUI/              # Shared UI components
│   └── LocumTrackerOCR/             # OCR engine for receipts
└── doc/
```

## Building the iOS App

### Opening the Project

```bash
cd locumtracker/LocumTracker
open LocumTracker.xcodeproj
```

Or open directly from Finder by double-clicking `LocumTracker/LocumTracker.xcodeproj`.

### Building from Xcode

1. Select the `LocumTracker` scheme
2. Select your target device (simulator or physical device)
3. Press `Cmd+B` to build, or `Cmd+R` to build and run

### Building from Command Line

```bash
# Build for simulator
cd LocumTracker
xcodebuild -scheme LocumTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Build for a specific simulator by ID
xcodebuild -scheme LocumTracker \
  -destination 'id=<simulator-uuid>' \
  build

# List available simulators
xcrun simctl list devices available
```

## Building Swift Packages

The packages can be built independently for faster iteration and testing.

### Build All Packages

```bash
# From repository root
swift build --package-path Packages/LocumTrackerCore
swift build --package-path Packages/LocumTrackerStorage
swift build --package-path Packages/LocumTrackerUI
swift build --package-path Packages/LocumTrackerOCR
```

### Run Package Tests

```bash
# Run all tests for a package
swift test --package-path Packages/LocumTrackerCore

# Run a specific test class
swift test --package-path Packages/LocumTrackerCore --filter RuralSubsidyServiceTests

# Run a specific test method
swift test --package-path Packages/LocumTrackerCore --filter "RuralSubsidyServiceTests/testSessionEligibility"
```

## Common Build Problems and Solutions

### 1. Package Resolution Failures

**Symptom:** Xcode shows "Package resolution failed" or packages appear with exclamation marks.

**Solutions:**

```bash
# Reset package cache
cd LocumTracker
rm -rf ~/Library/Developer/Xcode/DerivedData/LocumTracker-*
rm -rf .swiftpm

# In Xcode: File > Packages > Reset Package Caches
# Then: File > Packages > Resolve Package Versions
```

If using local packages that Xcode can't find:
1. Open the project in Xcode
2. Navigate to the project settings (click on project in navigator)
3. Check that package dependencies point to correct local paths

### 2. Module Not Found Errors

**Symptom:** `No such module 'LocumTrackerCore'` or similar errors.

**Causes & Solutions:**

1. **Package not linked to target:**
   - Select the app target in Xcode
   - Go to "General" > "Frameworks, Libraries, and Embedded Content"
   - Ensure all required packages are listed (LocumTrackerCore, LocumTrackerStorage, etc.)
   - If missing, click "+" and add them

2. **Build order issues:**
   ```bash
   # Clean build folder
   xcodebuild clean -scheme LocumTracker
   # Or in Xcode: Cmd+Shift+K

   # Then rebuild
   xcodebuild -scheme LocumTracker build
   ```

3. **Derived data corruption:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/LocumTracker-*
   ```

### 3. SwiftData/SwiftUI Compatibility Issues

**Symptom:** Errors about `@Model`, `@Query`, or other SwiftData macros.

**Solution:** Ensure deployment target is iOS 17+ for SwiftData features:
- In Xcode, select project > target > General > Minimum Deployments
- Set iOS to 17.0 or later

### 4. Local Package Changes Not Reflecting

**Symptom:** Changes to package code don't appear when building the app.

**Solutions:**

1. **Force package refresh:**
   - In Xcode: Product > Clean Build Folder (Cmd+Shift+K)
   - Then rebuild

2. **Check package is using local path:**
   - File > Packages > Update to Latest Package Versions

3. **Verify Package.swift is valid:**
   ```bash
   swift package --package-path Packages/LocumTrackerCore describe
   ```

### 5. Signing & Capabilities Errors

**Symptom:** Errors about code signing, provisioning profiles, or capabilities.

**Solutions:**

1. **Set your development team:**
   - Select project > Signing & Capabilities
   - Choose your team from the dropdown

2. **For CloudKit:**
   - Ensure iCloud capability is added
   - Container identifier matches: `iCloud.com.hherb.locumtracker`

### 6. LocumTrackerOCR Build Issues

**Symptom:** ONNX Runtime or OCR-related build failures.

The OCR package has external dependencies. If you encounter issues:

```bash
# Check package dependencies resolve
swift package --package-path Packages/LocumTrackerOCR resolve

# If ONNX models are missing, they should be in:
# Packages/LocumTrackerOCR/Sources/LocumTrackerOCR/Resources/
```

### 7. Simulator Architecture Mismatch

**Symptom:** Build fails with architecture errors on Apple Silicon Macs.

**Solution:**
```bash
# Build specifically for arm64 simulator
xcodebuild -scheme LocumTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16,arch=arm64' \
  build
```

## Clean Build Steps

When in doubt, perform a complete clean build:

```bash
# 1. Close Xcode

# 2. Clean all derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/LocumTracker-*

# 3. Clean package caches
cd LocumTracker
rm -rf .swiftpm
rm -rf ~/Library/Caches/org.swift.swiftpm/

# 4. Clean package build artifacts
rm -rf Packages/LocumTrackerCore/.build
rm -rf Packages/LocumTrackerStorage/.build
rm -rf Packages/LocumTrackerUI/.build
rm -rf Packages/LocumTrackerOCR/.build

# 5. Reopen project and rebuild
open LocumTracker.xcodeproj
```

## Build Verification

After building, verify everything works:

```bash
# Run package tests
swift test --package-path Packages/LocumTrackerCore

# Check the app launches in simulator
xcrun simctl boot "iPhone 16"
xcodebuild -scheme LocumTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Run the app
xcrun simctl launch booted com.hherb.LocumTracker
```

## CI/CD Considerations

For automated builds:

```bash
# Non-interactive build
xcodebuild -scheme LocumTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -quiet \
  build

# Build with specific configuration
xcodebuild -scheme LocumTracker \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  build
```

## Quick Reference

| Task | Command |
|------|---------|
| Open project | `open LocumTracker/LocumTracker.xcodeproj` |
| Build app (CLI) | `cd LocumTracker && xcodebuild -scheme LocumTracker build` |
| Build Core package | `swift build --package-path Packages/LocumTrackerCore` |
| Run Core tests | `swift test --package-path Packages/LocumTrackerCore` |
| Clean derived data | `rm -rf ~/Library/Developer/Xcode/DerivedData/LocumTracker-*` |
| Reset packages | In Xcode: File > Packages > Reset Package Caches |

## Getting Help

- Check existing issues on GitHub
- Review error messages carefully - Xcode often suggests fixes
- For package issues, try building the package in isolation first
- See `doc/developers/README.md` for general development guidance
