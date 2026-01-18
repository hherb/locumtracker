import Foundation

/// Handles Australian tax calculations including GST and ABN validation
/// Supports GST-registered and non-GST registered businesses
public struct TaxService {
    
    // MARK: - Constants
    
    /// Australian GST rate (10% as of 2024)
    public static let gstRate: Double = 0.10
    
    /// GST registration threshold for requiring ABN on invoices
    public static let abnThresholdAmount: Double = 1000.00
    
    /// Minimum invoice amount requiring customer ABN (B2B transactions)
    public static let customerABNThreshold: Double = 82.50
    
    // MARK: - Public Interface
    
    /// Calculates GST for an amount based on GST registration status
    /// - Parameters:
    ///   - amount: Pre-GST amount
    ///   - isGSTRegistered: Whether business is GST-registered
    /// - Returns: Detailed GST calculation
    public static func calculateGST(
        amount: Double,
        isGSTRegistered: Bool
    ) -> GSTCalculation {
        
        let gstAmount = isGSTRegistered ? amount * gstRate : 0.0
        let totalIncludingGST = amount + gstAmount
        
        return GSTCalculation(
            amount: amount,
            gstAmount: gstAmount,
            totalIncludingGST: totalIncludingGST,
            gstRate: gstRate,
            isGSTRegistered: isGSTRegistered
        )
    }
    
    /// Validates Australian Business Number (ABN) using checksum algorithm
    /// - Parameter abn: ABN string to validate
    /// - Returns: True if ABN is valid format and passes checksum
    public static func validateABN(_ abn: String) -> Bool {
        
        // Clean ABN by removing spaces and non-digits
        let cleanABN = abn.replacingOccurrences(of: " ", with: "")
                                     .replacingOccurrences(of: "-", with: "")
                                     .filter { $0.isNumber }
        
        // ABN must be 11 digits
        guard cleanABN.count == 11 else { return false }
        
        // Convert to array of integers
        let digits = cleanABN.compactMap { $0.wholeNumberValue }
        guard digits.count == 11 else { return false }
        
        // Apply ABN checksum algorithm
        var weights = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21]
        var sum = 0
        
        for (index, digit) in digits.enumerated() {
            sum += digit * weights[index]
        }
        
        // ABN is valid if sum modulo 89 equals 0
        return sum % 89 == 0
    }
    
    /// Determines if GST should be applied to an invoice
    /// - Parameters:
    ///   - isGSTRegistered: Whether seller is GST-registered
    ///   - hasValidABN: Whether seller has valid ABN
    ///   - invoiceAmount: Total invoice amount
    /// - Returns: True if GST should be applied
    public static func shouldApplyGST(
        isGSTRegistered: Bool,
        hasValidABN: Bool,
        invoiceAmount: Double
    ) -> Bool {
        return isGSTRegistered && hasValidABN && invoiceAmount >= customerABNThreshold
    }
    
    /// Determines if customer ABN is required on invoice
    /// - Parameter invoiceAmount: Total invoice amount
    /// - Returns: True if customer ABN is required
    public static func requiresCustomerABN(_ invoiceAmount: Double) -> Bool {
        return invoiceAmount >= customerABNThreshold
    }
    
    /// Formats an ABN with proper spacing
    /// - Parameter abn: ABN string to format
    /// - Returns: Formatted ABN (XX XXX XXX XXX)
    public static func formatABN(_ abn: String) -> String {
        let cleanABN = abn.replacingOccurrences(of: " ", with: "")
                                     .replacingOccurrences(of: "-", with: "")
        
        guard cleanABN.count == 11 else { return abn }
        
        let formatted = String(cleanABN.prefix(2)) + " " +
                      String(cleanABN.dropFirst(2).prefix(3)) + " " +
                      String(cleanABN.dropFirst(5).prefix(3)) + " " +
                      String(cleanABN.dropFirst(8))
        
        return formatted
    }
    
    /// Calculates total GST payable for a period
    /// - Parameters:
    ///   - taxableAmounts: Array of taxable amounts
    ///   - isGSTRegistered: Whether business is GST-registered
    /// - Returns: Total GST calculation
    public static func calculatePeriodGST(
        taxableAmounts: [Double],
        isGSTRegistered: Bool
    ) -> GSTCalculation {
        
        let totalTaxableAmount = taxableAmounts.reduce(0, +)
        let totalGST = isGSTRegistered ? totalTaxableAmount * gstRate : 0.0
        
        return GSTCalculation(
            amount: totalTaxableAmount,
            gstAmount: totalGST,
            totalIncludingGST: totalTaxableAmount + totalGST,
            gstRate: gstRate,
            isGSTRegistered: isGSTRegistered
        )
    }
    
    /// Generates GST-compliant invoice line items
    /// - Parameters:
    ///   - items: Array of invoice line items
    ///   - isGSTRegistered: Whether GST applies
    /// - Returns: Array of formatted invoice lines
    public static func generateInvoiceLines(
        items: [InvoiceItem],
        isGSTRegistered: Bool
    ) -> [InvoiceLine] {
        
        var lines: [InvoiceLine] = []
        
        for item in items {
            let gstCalculation = calculateGST(amount: item.amount, isGSTRegistered: isGSTRegistered)
            
            let line = InvoiceLine(
                description: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                lineTotal: item.amount,
                gstAmount: gstCalculation.gstAmount,
                totalIncludingGST: gstCalculation.totalIncludingGST
            )
            
            lines.append(line)
        }
        
        return lines
    }
    
    /// Validates invoice for GST compliance
    /// - Parameters:
    ///   - invoice: Invoice data to validate
    ///   - isGSTRegistered: Whether business is GST-registered
    /// - Returns: Validation result with any issues
    public static func validateGSTCompliance(
        invoice: InvoiceData,
        isGSTRegistered: Bool
    ) -> GSTValidation {
        
        var issues: [String] = []
        
        // Check ABN if required
        if requiresCustomerABN(invoice.totalAmount) && invoice.customerABN?.isEmpty != false {
            issues.append("Customer ABN required for invoices over $\(String(format: "%.2f", customerABNThreshold))")
        }
        
        // Check GST calculation if GST registered
        if isGSTRegistered {
            let expectedGST = invoice.totalAmount * gstRate
            let tolerance = 0.01 // Allow 1 cent rounding difference
            if abs((invoice.gstAmount ?? 0) - expectedGST) > tolerance {
                issues.append("GST amount calculation appears incorrect")
            }
        }
        
        // Check if GST should be zero when not GST registered
        if !isGSTRegistered && (invoice.gstAmount ?? 0) > 0 {
            issues.append("GST amount should be $0.00 when not GST registered")
        }
        
        return GSTValidation(
            isValid: issues.isEmpty,
            issues: issues,
            requiresGST: shouldApplyGST(
                isGSTRegistered: isGSTRegistered,
                hasValidABN: invoice.hasValidABN ?? false,
                invoiceAmount: invoice.totalAmount
            )
        )
    }
}

// MARK: - Supporting Types

/// Result of GST calculation
public struct GSTCalculation: Codable {
    /// Pre-GST amount
    public let amount: Double
    
    /// GST amount calculated
    public let gstAmount: Double
    
    /// Total including GST
    public let totalIncludingGST: Double
    
    /// GST rate used (typically 0.10)
    public let gstRate: Double
    
    /// Whether GST was applied (based on registration status)
    public let isGSTRegistered: Bool
    
    /// Initialize GST calculation
    /// - Parameters:
    ///   - amount: Pre-GST amount
    ///   - gstAmount: GST amount
    ///   - totalIncludingGST: Total including GST
    ///   - gstRate: GST rate used
    ///   - isGSTRegistered: Whether GST registered
    public init(
        amount: Double,
        gstAmount: Double,
        totalIncludingGST: Double,
        gstRate: Double,
        isGSTRegistered: Bool
    ) {
        self.amount = amount
        self.gstAmount = gstAmount
        self.totalIncludingGST = totalIncludingGST
        self.gstRate = gstRate
        self.isGSTRegistered = isGSTRegistered
    }
    
    /// Returns formatted GST amount
    public var formattedGSTAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: gstAmount)) ?? "$0.00"
    }
    
    /// Returns formatted total including GST
    public var formattedTotalIncludingGST: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: totalIncludingGST)) ?? "$0.00"
    }
    
    /// Returns formatted amount (pre-GST)
    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

/// Result of GST validation
public struct GSTValidation: Codable {
    /// Whether the invoice passes GST compliance checks
    public let isValid: Bool
    
    /// Array of compliance issues found
    public let issues: [String]
    
    /// Whether GST should be applied to this invoice
    public let requiresGST: Bool
    
    /// Initialize GST validation
    /// - Parameters:
    ///   - isValid: Whether valid
    ///   - issues: List of issues
    ///   - requiresGST: Whether GST required
    public init(isValid: Bool, issues: [String], requiresGST: Bool) {
        self.isValid = isValid
        self.issues = issues
        self.requiresGST = requiresGST
    }
}

/// Invoice line item
public struct InvoiceItem: Codable {
    /// Description of the item
    public let description: String
    
    /// Quantity of the item
    public let quantity: Double
    
    /// Unit price of the item
    public let unitPrice: Double
    
    /// Total amount for the item (quantity × unit price)
    public var amount: Double {
        return quantity * unitPrice
    }
    
    /// Initialize invoice item
    /// - Parameters:
    ///   - description: Item description
    ///   - quantity: Item quantity
    ///   - unitPrice: Unit price
    public init(description: String, quantity: Double, unitPrice: Double) {
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
    }
}

/// Formatted invoice line
public struct InvoiceLine: Codable {
    /// Item description
    public let description: String
    
    /// Item quantity
    public let quantity: Double
    
    /// Unit price
    public let unitPrice: Double
    
    /// Line total (pre-GST)
    public let lineTotal: Double
    
    /// GST amount for this line
    public let gstAmount: Double
    
    /// Line total including GST
    public let totalIncludingGST: Double
    
    /// Initialize invoice line
    /// - Parameters:
    ///   - description: Item description
    ///   - quantity: Quantity
    ///   - unitPrice: Unit price
    ///   - lineTotal: Line total
    ///   - gstAmount: GST amount
    ///   - totalIncludingGST: Total including GST
    public init(
        description: String,
        quantity: Double,
        unitPrice: Double,
        lineTotal: Double,
        gstAmount: Double,
        totalIncludingGST: Double
    ) {
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal
        self.gstAmount = gstAmount
        self.totalIncludingGST = totalIncludingGST
    }
    
    /// Returns formatted unit price
    public var formattedUnitPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: unitPrice)) ?? "$0.00"
    }
    
    /// Returns formatted line total
    public var formattedLineTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: lineTotal)) ?? "$0.00"
    }
    
    /// Returns formatted GST amount
    public var formattedGSTAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: gstAmount)) ?? "$0.00"
    }
    
    /// Returns formatted total including GST
    public var formattedTotalIncludingGST: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: totalIncludingGST)) ?? "$0.00"
    }
}

/// Invoice data for GST validation
public struct InvoiceData {
    /// Total invoice amount
    public let totalAmount: Double
    
    /// GST amount calculated
    public let gstAmount: Double?
    
    /// Customer ABN (if required)
    public let customerABN: String?
    
    /// Whether seller has valid ABN
    public let hasValidABN: Bool?
    
    /// Initialize invoice data
    /// - Parameters:
    ///   - totalAmount: Total amount
    ///   - gstAmount: GST amount
    ///   - customerABN: Customer ABN
    ///   - hasValidABN: Whether seller ABN is valid
    public init(
        totalAmount: Double,
        gstAmount: Double? = nil,
        customerABN: String? = nil,
        hasValidABN: Bool? = nil
    ) {
        self.totalAmount = totalAmount
        self.gstAmount = gstAmount
        self.customerABN = customerABN
        self.hasValidABN = hasValidABN
    }
}