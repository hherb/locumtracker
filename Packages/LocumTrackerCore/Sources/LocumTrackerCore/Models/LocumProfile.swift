import Foundation

/// User profile and professional details for locum practitioners
/// Includes ABN, GST registration, and rate preferences
@Model
public final class LocumProfile {
    /// Unique identifier for the profile
    public var id: UUID
    
    /// First name of the practitioner
    public var firstName: String
    
    /// Last name of the practitioner
    public var lastName: String
    
    /// Email address for communication and invoices
    public var email: String
    
    /// Australian Business Number for tax purposes
    public var abn: String?
    
    /// Whether the practitioner is registered for GST
    public var gstRegistered: Bool = false
    
    /// Whether the practitioner has vocational registration (affects subsidy rates)
    public var isVocational: Bool = true
    
    /// Default daily rate for new assignments
    public var defaultDailyRate: Double
    
    /// Default hourly rate for new assignments
    public var defaultHourlyRate: Double
    
    /// Default on-call rate for new assignments
    public var defaultOnCallRate: Double?
    
    /// Default call-out rate for new assignments
    public var defaultCallOutRate: Double?
    
    /// Payment details for invoices
    public var paymentDetails: PaymentDetails
    
    /// Provider number for Medicare/Medical Board
    public var providerNumber: String?
    
    /// Specialty of the practitioner
    public var specialty: String?
    
    /// Date when this profile was created
    public var createdAt: Date
    
    /// Date when this profile was last updated
    public var updatedAt: Date
    
    /// Initialize a new locum profile
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - firstName: First name
    ///   - lastName: Last name
    ///   - email: Email address
    ///   - abn: Optional Australian Business Number
    ///   - gstRegistered: Whether GST registered
    ///   - isVocational: Whether vocationally registered
    ///   - defaultDailyRate: Default daily rate
    ///   - defaultHourlyRate: Default hourly rate
    ///   - defaultOnCallRate: Optional default on-call rate
    ///   - defaultCallOutRate: Optional default call-out rate
    ///   - paymentDetails: Payment information for invoices
    ///   - providerNumber: Optional provider number
    ///   - specialty: Optional medical specialty
    public init(
        id: UUID,
        firstName: String,
        lastName: String,
        email: String,
        abn: String? = nil,
        gstRegistered: Bool = false,
        isVocational: Bool = true,
        defaultDailyRate: Double,
        defaultHourlyRate: Double,
        defaultOnCallRate: Double? = nil,
        defaultCallOutRate: Double? = nil,
        paymentDetails: PaymentDetails,
        providerNumber: String? = nil,
        specialty: String? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.abn = abn
        self.gstRegistered = gstRegistered
        self.isVocational = isVocational
        self.defaultDailyRate = defaultDailyRate
        self.defaultHourlyRate = defaultHourlyRate
        self.defaultOnCallRate = defaultOnCallRate
        self.defaultCallOutRate = defaultCallOutRate
        self.paymentDetails = paymentDetails
        self.providerNumber = providerNumber
        self.specialty = specialty
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Returns the full name of the practitioner
    public var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    /// Returns the ABN formatted with spaces
    public var formattedABN: String? {
        guard let abn = abn else { return nil }
        
        let cleanABN = abn.replacingOccurrences(of: " ", with: "")
        guard cleanABN.count == 11 else { return abn }
        
        let withSpaces = String(cleanABN.prefix(2)) + " " +
                       String(cleanABN.dropFirst(2).prefix(3)) + " " +
                       String(cleanABN.dropFirst(5).prefix(3)) + " " +
                       String(cleanABN.dropFirst(8))
        
        return withSpaces
    }
    
    /// Validates the ABN format and checksum
    public var hasValidABN: Bool {
        guard let abn = abn else { return false }
        return TaxService.validateABN(abn)
    }
    
    /// Returns formatted email for display
    public var formattedEmail: String {
        return email.lowercased()
    }
    
    /// Determines if GST should be applied to invoices
    public var shouldApplyGST: Bool {
        return gstRegistered && hasValidABN
    }
    
    /// Returns the default rate based on assignment structure
    /// - Parameter rateStructure: Daily or hourly rate structure
    /// - Returns: Applicable default rate
    public func defaultRate(for rateStructure: RateStructure) -> Double {
        switch rateStructure {
        case .dailyRate: return defaultDailyRate
        case .hourlyRate: return defaultHourlyRate
        }
    }
    
    /// Returns subsidy rate multiplier based on vocational status
    public var subsidyRateMultiplier: Double {
        return isVocational ? 1.0 : 0.8
    }
    
    /// Updates the profile timestamp
    public func touch() {
        self.updatedAt = Date()
    }
}

/// Payment details for invoice generation
public struct PaymentDetails: Codable {
    /// Bank account name
    public var bankName: String
    
    /// Bank account number
    public var accountNumber: String
    
    /// Bank BSB number (Australian banks)
    public var bsbNumber: String?
    
    /// Account holder name
    public var accountHolderName: String
    
    /// PayPal email address (alternative payment method)
    public var paypalEmail: String?
    
    /// Preferred payment method
    public var preferredMethod: PaymentMethod
    
    /// Initialize payment details
    /// - Parameters:
    ///   - bankName: Bank name
    ///   - accountNumber: Bank account number
    ///   - bsbNumber: Optional BSB number
    ///   - accountHolderName: Account holder name
    ///   - paypalEmail: Optional PayPal email
    ///   - preferredMethod: Preferred payment method
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
    
    /// Returns masked account number for display
    public var maskedAccountNumber: String {
        guard accountNumber.count > 4 else { return accountNumber }
        let lastFour = String(accountNumber.suffix(4))
        let masked = String(repeating: "*", count: accountNumber.count - 4) + lastFour
        return masked
    }
    
    /// Returns formatted BSB if available
    public var formattedBSB: String? {
        guard let bsbNumber = bsbNumber else { return nil }
        let clean = bsbNumber.replacingOccurrences(of: "-", with: "")
        guard clean.count == 6 else { return bsbNumber }
        return String(clean.prefix(3)) + "-" + String(clean.dropFirst(3))
    }
}

/// Available payment methods
public enum PaymentMethod: String, CaseIterable, Codable {
    case bankTransfer = "bank_transfer"
    case paypal = "paypal"
    case check = "check"
    
    /// Human-readable description of payment method
    public var description: String {
        switch self {
        case .bankTransfer: return "Bank Transfer"
        case .paypal: return "PayPal"
        case .check: return "Check"
        }
    }
    
    /// Icon for payment method
    public var icon: String {
        switch self {
        case .bankTransfer: return "🏦"
        case .paypal: return "💰"
        case .check: return "📝"
        }
    }
}