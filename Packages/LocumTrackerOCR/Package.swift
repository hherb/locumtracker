// LocumTracker
// Copyright (C) 2025 Dr Horst Herb
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
