// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocumTrackerStorage",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LocumTrackerStorage",
            targets: ["LocumTrackerStorage"]
        ),
    ],
    dependencies: [
        .package(path: "../LocumTrackerCore"),
    ],
    targets: [
        .target(
            name: "LocumTrackerStorage",
            dependencies: ["LocumTrackerCore"]
        ),
        .testTarget(
            name: "LocumTrackerStorageTests",
            dependencies: ["LocumTrackerStorage"]
        ),
    ]
)
