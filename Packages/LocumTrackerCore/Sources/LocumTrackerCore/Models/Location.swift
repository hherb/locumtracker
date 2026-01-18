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
    public var id: UUID
    public var name: String
    public var address: String
    public var mmmClassification: Int
    public var latitude: Double?
    public var longitude: Double?
    public var effectiveFrom: Date
    public var effectiveTo: Date?
    public var createdAt: Date
    public var updatedAt: Date

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
