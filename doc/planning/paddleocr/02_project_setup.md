# Phase 2: Project Setup

Configure your Xcode project with ONNX Runtime dependencies and add the model files.

## Option A: Swift Package Manager (Recommended)

Add to `Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LocumTrackerOCR",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "LocumTrackerOCR", targets: ["LocumTrackerOCR"])
    ],
    dependencies: [
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager", from: "1.16.0")
    ],
    targets: [
        .target(
            name: "LocumTrackerOCR",
            dependencies: [
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager")
            ],
            resources: [
                .copy("Resources/OCRModels")
            ]
        )
    ]
)
```

## Option B: CocoaPods

```ruby
# Podfile
platform :ios, '15.0'

target 'LocumTracker' do
  use_frameworks!

  pod 'onnxruntime-objc', '~> 1.16.0'
  # Or for smaller size with CoreML support:
  pod 'onnxruntime-mobile-objc', '~> 1.16.0'
end
```

## Add Models to Xcode Project

1. Drag `Resources/OCRModels` folder into Xcode project navigator
2. Ensure "Copy items if needed" is checked
3. Add to target membership for both iOS and macOS targets
4. Verify models appear in "Copy Bundle Resources" build phase

---

**Previous:** [01_model_preparation.md](01_model_preparation.md)
**Next:** [03_core_implementation.md](03_core_implementation.md) - OCREngine with detection and recognition
