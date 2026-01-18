// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocumTrackerStorage",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LocumTrackerStorage",
            targets: ["LocumTrackerStorage"]
        ),
    ],
    dependencies: [
        .package(name: "LocumTrackerCore", path: "../LocumTrackerCore"),
    ],
    targets: [
        .target(
            name: "LocumTrackerStorage",
            dependencies: ["LocumTrackerCore"],
            path: "Sources/LocumTrackerStorage"
        ),
        .testTarget(
            name: "LocumTrackerStorageTests",
            dependencies: ["LocumTrackerStorage"],
            path: "Tests/LocumTrackerStorageTests"
        ),
    ]
)