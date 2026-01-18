// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocumTrackerCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LocumTrackerCore",
            targets: ["LocumTrackerCore"]
        ),
    ],
    targets: [
        .target(
            name: "LocumTrackerCore",
            dependencies: []
        ),
        .testTarget(
            name: "LocumTrackerCoreTests",
            dependencies: ["LocumTrackerCore"]
        ),
    ]
)
