// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocumTrackerUI",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LocumTrackerUI",
            targets: ["LocumTrackerUI"]
        ),
    ],
    dependencies: [
        .package(name: "LocumTrackerCore", path: "../LocumTrackerCore"),
    ],
    targets: [
        .target(
            name: "LocumTrackerUI",
            dependencies: ["LocumTrackerCore"],
            path: "Sources/LocumTrackerUI"
        ),
        .testTarget(
            name: "LocumTrackerUITests",
            dependencies: ["LocumTrackerUI"],
            path: "Tests/LocumTrackerUITests"
        ),
    ]
)