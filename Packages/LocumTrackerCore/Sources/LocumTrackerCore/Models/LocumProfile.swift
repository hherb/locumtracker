import Foundation
import SwiftData

/// Available payment methods
public enum PaymentMethod: String, CaseIterable, Codable, Sendable {
    case bankTransfer = "bank_transfer"
    case paypal = "paypal"
    case cheque = "cheque"

    public var description: String {
        switch self {
        case .bankTransfer: return "Bank Transfer"
        case .paypal: return "PayPal"
        case .cheque: return "Cheque"
        }
    }
}

/// Business structure types for Australian businesses
public enum BusinessStructure: String, CaseIterable, Codable, Sendable {
    case individual = "individual"
    case soleTrader = "sole_trader"
    case company = "company"
    case trust = "trust"
    case partnership = "partnership"

    public var description: String {
        switch self {
        case .individual: return "Individual"
        case .soleTrader: return "Sole Trader"
        case .company: return "Company (Pty Ltd)"
        case .trust: return "Trust"
        case .partnership: return "Partnership"
        }
    }
}

/// Professional title prefixes
public enum ProfessionalTitle: String, CaseIterable, Codable, Sendable {
    case dr = "Dr"
    case prof = "Prof"
    case assocProf = "A/Prof"
    case mr = "Mr"
    case ms = "Ms"
    case mrs = "Mrs"
    case none = ""

    public var description: String {
        switch self {
        case .dr: return "Dr"
        case .prof: return "Professor"
        case .assocProf: return "Associate Professor"
        case .mr: return "Mr"
        case .ms: return "Ms"
        case .mrs: return "Mrs"
        case .none: return "None"
        }
    }
}

/// Payment details for invoice generation
public struct PaymentDetails: Codable, Sendable {
    public var bankName: String
    public var accountNumber: String
    public var bsbNumber: String?
    public var accountHolderName: String
    public var paypalEmail: String?
    public var preferredMethod: PaymentMethod

    public init(
        bankName: String,
        accountNumber: String,
        bsbNumber: String? = nil,
        accountHolderName: String,
        paypalEmail: String? = nil,
        preferredMethod: PaymentMethod = .bankTransfer
    ) {
        self.bankName = bankName
        self.accountNumber = accountNumber
        self.bsbNumber = bsbNumber
        self.accountHolderName = accountHolderName
        self.paypalEmail = paypalEmail
        self.preferredMethod = preferredMethod
    }

    /// Returns formatted BSB (XXX-XXX)
    public var formattedBSB: String? {
        guard let bsb = bsbNumber else { return nil }
        let clean = bsb.replacingOccurrences(of: "-", with: "")
        guard clean.count == 6 else { return bsb }
        return String(clean.prefix(3)) + "-" + String(clean.suffix(3))
    }
}

/// User profile and professional details for locum practitioners
@Model
public final class LocumProfile {
    public var id: UUID = UUID()

    // Personal Information
    public var titleRaw: String = ProfessionalTitle.dr.rawValue
    public var firstName: String = ""
    public var lastName: String = ""
    public var email: String = ""

    // Address for invoicing
    public var streetAddress: String = ""
    public var suburb: String = ""
    public var state: String = ""
    public var postcode: String = ""

    // Business & Tax Details
    public var businessStructureRaw: String = BusinessStructure.individual.rawValue
    public var abn: String?
    public var gstRegistered: Bool = false

    // Professional Details
    public var isVocational: Bool = true
    public var providerNumber: String?
    public var specialty: String?

    // Default Rates
    public var defaultDailyRate: Double = 0
    public var defaultHourlyRate: Double = 0
    public var defaultOnCallRate: Double?
    public var defaultCallOutRate: Double?

    // Timestamps
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    // Store payment details as JSON since SwiftData doesn't support nested Codable structs directly
    public var paymentDetailsJSON: Data?

    /// Professional title (stored as raw string for SwiftData compatibility)
    public var title: ProfessionalTitle {
        get { ProfessionalTitle(rawValue: titleRaw) ?? .dr }
        set { titleRaw = newValue.rawValue }
    }

    /// Business structure (stored as raw string for SwiftData compatibility)
    public var businessStructure: BusinessStructure {
        get { BusinessStructure(rawValue: businessStructureRaw) ?? .individual }
        set { businessStructureRaw = newValue.rawValue }
    }

    /// Creates a new locum profile
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - title: Professional title prefix (Dr, Prof, etc.)
    ///   - firstName: First name
    ///   - lastName: Last name
    ///   - email: Email address
    ///   - streetAddress: Street address for invoicing
    ///   - suburb: Suburb/city
    ///   - state: State/territory (e.g., NSW, VIC)
    ///   - postcode: Postal code
    ///   - businessStructure: Business structure type
    ///   - abn: Australian Business Number (optional)
    ///   - gstRegistered: Whether registered for GST
    ///   - isVocational: Whether vocationally registered
    ///   - defaultDailyRate: Default daily rate for new assignments
    ///   - defaultHourlyRate: Default hourly rate for new assignments
    ///   - defaultOnCallRate: Default on-call rate (optional)
    ///   - defaultCallOutRate: Default call-out rate (optional)
    ///   - providerNumber: Medicare provider number (optional)
    ///   - specialty: Medical specialty (optional)
    public init(
        id: UUID = UUID(),
        title: ProfessionalTitle = .dr,
        firstName: String,
        lastName: String,
        email: String,
        streetAddress: String = "",
        suburb: String = "",
        state: String = "",
        postcode: String = "",
        businessStructure: BusinessStructure = .individual,
        abn: String? = nil,
        gstRegistered: Bool = false,
        isVocational: Bool = true,
        defaultDailyRate: Double,
        defaultHourlyRate: Double,
        defaultOnCallRate: Double? = nil,
        defaultCallOutRate: Double? = nil,
        providerNumber: String? = nil,
        specialty: String? = nil
    ) {
        self.id = id
        self.titleRaw = title.rawValue
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.streetAddress = streetAddress
        self.suburb = suburb
        self.state = state
        self.postcode = postcode
        self.businessStructureRaw = businessStructure.rawValue
        self.abn = abn
        self.gstRegistered = gstRegistered
        self.isVocational = isVocational
        self.defaultDailyRate = defaultDailyRate
        self.defaultHourlyRate = defaultHourlyRate
        self.defaultOnCallRate = defaultOnCallRate
        self.defaultCallOutRate = defaultCallOutRate
        self.providerNumber = providerNumber
        self.specialty = specialty
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Full name of the practitioner (without title)
    public var fullName: String {
        "\(firstName) \(lastName)"
    }

    /// Full name with professional title
    public var formalName: String {
        if title == .none {
            return fullName
        }
        return "\(title.rawValue) \(firstName) \(lastName)"
    }

    /// Formatted address for invoicing (multi-line, Australian format)
    ///
    /// Format: Street Address
    ///         SUBURB STATE POSTCODE
    public var formattedAddress: String? {
        var lines: [String] = []

        if !streetAddress.isEmpty {
            lines.append(streetAddress)
        }

        // Australian address format: SUBURB STATE POSTCODE (all caps for suburb traditionally)
        var localityLine = ""
        if !suburb.isEmpty {
            localityLine = suburb
        }
        if !state.isEmpty {
            localityLine += localityLine.isEmpty ? state : " \(state)"
        }
        if !postcode.isEmpty {
            localityLine += localityLine.isEmpty ? postcode : " \(postcode)"
        }

        if !localityLine.isEmpty {
            lines.append(localityLine)
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// Single-line address for compact display
    public var addressOneLine: String? {
        var parts: [String] = []

        if !streetAddress.isEmpty {
            parts.append(streetAddress)
        }
        if !suburb.isEmpty {
            parts.append(suburb)
        }
        if !state.isEmpty {
            parts.append(state)
        }
        if !postcode.isEmpty {
            parts.append(postcode)
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Returns the ABN formatted with spaces (XX XXX XXX XXX)
    public var formattedABN: String? {
        guard let abn = abn else { return nil }
        let clean = abn.replacingOccurrences(of: " ", with: "")
        guard clean.count == 11 else { return abn }
        return String(clean.prefix(2)) + " " +
               String(clean.dropFirst(2).prefix(3)) + " " +
               String(clean.dropFirst(5).prefix(3)) + " " +
               String(clean.suffix(3))
    }

    /// Subsidy rate multiplier based on vocational status (1.0 for vocational, 0.8 for non-vocational)
    public var subsidyRateMultiplier: Double {
        isVocational ? 1.0 : 0.8
    }
}
