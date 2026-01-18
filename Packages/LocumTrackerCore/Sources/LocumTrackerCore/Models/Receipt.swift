import Foundation
import SwiftData

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

    /// Whether this category is typically tax deductible
    public var isTaxDeductible: Bool {
        switch self {
        case .travel, .accommodation, .meals, .supplies, .professional, .insurance, .training:
            return true
        case .other:
            return false
        }
    }
}

/// Represents expense receipts for reimbursement and tax purposes
@Model
public final class Receipt {
    public var id: UUID = UUID()
    public var dailyRecordId: UUID?
    public var assignmentId: UUID?
    public var amount: Double = 0
    public var category: ExpenseCategory = ExpenseCategory.other
    public var imageData: Data?
    public var date: Date = Date()
    public var receiptDescription: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        amount: Double,
        category: ExpenseCategory,
        date: Date,
        receiptDescription: String,
        dailyRecordId: UUID? = nil,
        assignmentId: UUID? = nil,
        imageData: Data? = nil
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.date = date
        self.receiptDescription = receiptDescription
        self.dailyRecordId = dailyRecordId
        self.assignmentId = assignmentId
        self.imageData = imageData
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Whether this receipt has an associated image
    public var hasImage: Bool {
        imageData != nil
    }
}
