import Foundation

/// Represents expense receipts for reimbursement and tax purposes
/// Receipts can be linked to specific work days or assignments
@Model
public final class Receipt {
    /// Unique identifier for the receipt
    public var id: UUID
    
    /// ID of the daily record this receipt is associated with (if applicable)
    public var dailyRecordId: UUID?
    
    /// ID of the assignment this receipt is associated with (if applicable)
    public var assignmentId: UUID?
    
    /// Total amount of the receipt
    public var amount: Double
    
    /// Category of expense for tax purposes
    public var category: ExpenseCategory
    
    /// Image data of the receipt (compressed for CloudKit)
    public var imageData: Data?
    
    /// CloudKit asset reference for larger image files
    public var cloudAsset: CKAsset?
    
    /// Date of the receipt (when the expense was incurred)
    public var date: Date
    
    /// Description of the expense
    public var description: String
    
    /// Date when this receipt record was created
    public var createdAt: Date
    
    /// Date when this receipt record was last updated
    public var updatedAt: Date
    
    /// Initialize a new receipt
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - amount: Total amount of the receipt
    ///   - category: Category of expense
    ///   - date: Date the expense was incurred
    ///   - description: Description of the expense
    ///   - dailyRecordId: Optional associated daily record
    ///   - assignmentId: Optional associated assignment
    ///   - imageData: Optional receipt image data
    public init(
        id: UUID,
        amount: Double,
        category: ExpenseCategory,
        date: Date,
        description: String,
        dailyRecordId: UUID? = nil,
        assignmentId: UUID? = nil,
        imageData: Data? = nil
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.date = date
        self.description = description
        self.dailyRecordId = dailyRecordId
        self.assignmentId = assignmentId
        self.imageData = imageData
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Returns the amount formatted as currency
    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD" // Default to AUD for Australian focus
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    /// Returns the date formatted for display
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Determines if this receipt has an associated image
    public var hasImage: Bool {
        return imageData != nil || cloudAsset != nil
    }
    
    /// Returns the estimated size of the receipt image data
    public var estimatedImageSize: Int {
        return imageData?.count ?? 0
    }
    
    /// Determines if this receipt image needs compression for CloudKit
    public var needsCompression: Bool {
        return estimatedImageSize > 10 * 1024 * 1024 // 10MB limit
    }
    
    /// Updates the receipt timestamp
    public func touch() {
        self.updatedAt = Date()
    }
}

/// Categories of expenses for tax purposes
public enum ExpenseCategory: String, CaseIterable, Codable {
    case travel = "travel"
    case accommodation = "accommodation"
    case meals = "meals"
    case supplies = "supplies"
    case professional = "professional"
    case insurance = "insurance"
    case training = "training"
    case other = "other"
    
    /// Human-readable description of the expense category
    public var description: String {
        switch self {
        case .travel: return "Travel"
        case .accommodation: return "Accommodation"
        case .meals: return "Meals"
        case .supplies: return "Medical Supplies"
        case .professional: return "Professional Development"
        case .insurance: return "Insurance"
        case .training: return "Training"
        case .other: return "Other"
        }
    }
    
    /// Icon representing the expense category
    public var icon: String {
        switch self {
        case .travel: return "✈️"
        case .accommodation: return "🏨"
        case .meals: return "🍽️"
        case .supplies: return "🏥"
        case .professional: return "📚"
        case .insurance: return "🛡️"
        case .training: return "🎓"
        case .other: return "📄"
        }
    }
    
    /// Color associated with the expense category for UI
    public var uiColor: String {
        switch self {
        case .travel: return "blue"
        case .accommodation: return "purple"
        case .meals: return "green"
        case .supplies: return "red"
        case .professional: return "orange"
        case .insurance: return "yellow"
        case .training: return "indigo"
        case .other: return "gray"
        }
    }
    
    /// Determines if this category is typically tax deductible
    public var isTaxDeductible: Bool {
        switch self {
        case .travel, .accommodation, .meals, .supplies, .professional, .insurance, .training:
            return true
        case .other:
            return false // Needs manual review
        }
    }
}