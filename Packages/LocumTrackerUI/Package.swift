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
