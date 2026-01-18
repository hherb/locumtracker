import Foundation

/// Represents a physical location where locum work is performed
/// Includes Modified Monash Model classification for rural subsidy eligibility
@Model
public final class Location {
    /// Unique identifier for the location
    public var id: UUID
    
    /// Human-readable name of the location (e.g., "Cooktown Hospital")
    public var name: String
    
    /// Full street address
    public var address: String
    
    /// Modified Monash Model classification (1-7)
    /// 1: Major cities (≥1 million population)
    /// 2: Regional cities (50,000-1 million population)
    /// 3: Large rural towns (15,000-50, population)
    /// 4: Medium rural towns (5,000-15,000 population)
    /// 5: Small rural towns (1,000-5,000 population)
    /// 6: Remote communities (<1,000 population, >1 hour from major service)
    /// 7: Very remote communities (<1,000 population, >2 hours from major service)
    public var mmmClassification: Int
    
    /// Australian Statistical Geography Standard Remoteness Area classification
    public var asgsRA: Int?
    
    /// Latitude coordinate for location
    public var latitude: Double?
    
    /// Longitude coordinate for location
    public var longitude: Double?
    
    /// Date from which this location information is effective
    public var effectiveFrom: Date
    
    /// Date until which this location information is valid (nil for current)
    public var effectiveTo: Date?
    
    /// Date when this location record was created
    public var createdAt: Date
    
    /// Date when this location record was last updated
    public var updatedAt: Date
    
    /// Initialize a new location with the specified parameters
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - name: Human-readable name
    ///   - address: Full street address
    ///   - mmmClassification: Modified Monash Model classification (1-7)
    ///   - asgsRA: Optional ASGS RA classification
    ///   - latitude: Optional latitude coordinate
    ///   - longitude: Optional longitude coordinate
    ///   - effectiveFrom: Date when location becomes effective
    public init(
        id: UUID,
        name: String,
        address: String,
        mmmClassification: Int,
        asgsRA: Int? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        effectiveFrom: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.mmmClassification = mmmClassification
        self.asgsRA = asgsRA
        self.latitude = latitude
        self.longitude = longitude
        self.effectiveFrom = effectiveFrom
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Determines if this location is eligible for rural subsidy
    /// MMM 3-7 classifications are eligible for subsidy
    public var isRuralSubsidyEligible: Bool {
        return (3...7).contains(mmmClassification)
    }
    
    /// Returns the MMM classification as a descriptive string
    public var mmmClassificationDescription: String {
        switch mmmClassification {
        case 1: return "MMM1 - Major City"
        case 2: return "MMM2 - Regional City"
        case 3: return "MMM3 - Large Rural Town"
        case 4: return "MMM4 - Medium Rural Town"
        case 5: return "MMM5 - Small Rural Town"
        case 6: return "MMM6 - Remote Community"
        case 7: return "MMM7 - Very Remote Community"
        default: return "Unknown"
        }
    }
}