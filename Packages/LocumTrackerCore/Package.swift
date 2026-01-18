// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocumTrackerCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LocumTrackerCore",
            targets: ["LocumTrackerCore"]
        ),
    ],
    dependencies: [
        // No external dependencies - pure functions only
    ],
    targets: [
        .target(
            name: "LocumTrackerCore",
            dependencies: [],
            path: "Sources/LocumTrackerCore"
        ),
        .testTarget(
            name: "LocumTrackerCoreTests",
            dependencies: ["LocumTrackerCore"],
            path: "Tests/LocumTrackerCoreTests"
        ),
    ]
)