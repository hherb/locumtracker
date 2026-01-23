// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocumTrackerOCR",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "LocumTrackerOCR",
            targets: ["LocumTrackerOCR"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/microsoft/onnxruntime-swift-package-manager",
            from: "1.16.0"
        )
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
        ),
        .testTarget(
            name: "LocumTrackerOCRTests",
            dependencies: ["LocumTrackerOCR"],
            resources: [
                .copy("Resources/TestReceipts")
            ]
        ),
    ]
)
