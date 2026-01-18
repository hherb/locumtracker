// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocumTrackerUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LocumTrackerUI",
            targets: ["LocumTrackerUI"]
        ),
    ],
    dependencies: [
        .package(path: "../LocumTrackerCore"),
    ],
    targets: [
        .target(
            name: "LocumTrackerUI",
            dependencies: ["LocumTrackerCore"]
        ),
        .testTarget(
            name: "LocumTrackerUITests",
            dependencies: ["LocumTrackerUI"]
        ),
    ]
)
