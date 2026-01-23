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

import Foundation
import SwiftData

/// Modified Monash Model classification levels
public enum MMMClassification: Int, CaseIterable, Codable {
    case majorCity = 1
    case regionalCity = 2
    case largeRuralTown = 3
    case mediumRuralTown = 4
    case smallRuralTown = 5
    case remoteCommunity = 6
    case veryRemoteCommunity = 7

    public var description: String {
        switch self {
        case .majorCity: return "MMM1 - Major City"
        case .regionalCity: return "MMM2 - Regional City"
        case .largeRuralTown: return "MMM3 - Large Rural Town"
        case .mediumRuralTown: return "MMM4 - Medium Rural Town"
        case .smallRuralTown: return "MMM5 - Small Rural Town"
        case .remoteCommunity: return "MMM6 - Remote Community"
        case .veryRemoteCommunity: return "MMM7 - Very Remote Community"
        }
    }

    /// Whether this classification is eligible for rural subsidy (MMM3-7)
    public var isSubsidyEligible: Bool {
        rawValue >= 3
    }
}

/// Represents a physical location where locum work is performed
@Model
public final class Location {
    public var id: UUID = UUID()
    public var name: String = ""
    public var address: String = ""
    public var mmmClassification: Int = 1
    public var latitude: Double?
    public var longitude: Double?
    public var effectiveFrom: Date = Date()
    public var effectiveTo: Date?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        name: String,
        address: String,
        mmmClassification: Int,
        latitude: Double? = nil,
        longitude: Double? = nil,
        effectiveFrom: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.mmmClassification = mmmClassification
        self.latitude = latitude
        self.longitude = longitude
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Determines if this location is eligible for rural subsidy (MMM 3-7)
    public var isRuralSubsidyEligible: Bool {
        (3...7).contains(mmmClassification)
    }

    /// Returns the MMM classification as a descriptive string
    public var mmmClassificationDescription: String {
        MMMClassification(rawValue: mmmClassification)?.description ?? "Unknown"
    }
}
