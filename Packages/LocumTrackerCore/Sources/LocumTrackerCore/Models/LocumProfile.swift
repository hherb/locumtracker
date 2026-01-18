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
    public var firstName: String = ""
    public var lastName: String = ""
    public var email: String = ""
    public var abn: String?
    public var gstRegistered: Bool = false
    public var isVocational: Bool = true
    public var defaultDailyRate: Double = 0
    public var defaultHourlyRate: Double = 0
    public var defaultOnCallRate: Double?
    public var defaultCallOutRate: Double?
    public var providerNumber: String?
    public var specialty: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    // Store payment details as JSON since SwiftData doesn't support nested Codable structs directly
    public var paymentDetailsJSON: Data?

    public init(
        id: UUID = UUID(),
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
        self.providerNumber = providerNumber
        self.specialty = specialty
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Full name of the practitioner
    public var fullName: String {
        "\(firstName) \(lastName)"
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
