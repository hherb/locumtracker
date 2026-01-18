import Foundation

/// Handles validation of data and business rules
public struct ValidationService {

    // MARK: - Constants

    /// Maximum session duration (24 hours in seconds)
    public static let maxSessionDurationSeconds: TimeInterval = 86400

    /// Minimum session duration (1 minute in seconds)
    public static let minSessionDurationSeconds: TimeInterval = 60

    // MARK: - Validation Methods

    /// Validates MMM classification value (1-7)
    public static func isValidMMMClassification(_ classification: Int) -> Bool {
        (1...7).contains(classification)
    }

    /// Validates email address format
    public static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    /// Validates session duration is within allowed bounds
    public static func isValidSessionDuration(_ durationSeconds: TimeInterval) -> Bool {
        durationSeconds >= minSessionDurationSeconds && durationSeconds <= maxSessionDurationSeconds
    }

    /// Validates BSB format (6 digits, optionally with hyphen)
    public static func isValidBSB(_ bsb: String) -> Bool {
        let clean = bsb.replacingOccurrences(of: "-", with: "")
        return clean.count == 6 && clean.allSatisfy { $0.isNumber }
    }

    /// Validates date range (start before end)
    public static func isValidDateRange(start: Date, end: Date) -> Bool {
        start < end
    }

    /// Validates a rate is positive
    public static func isValidRate(_ rate: Double) -> Bool {
        rate > 0
    }
}

/// Result of a validation operation
public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [String]

    public init(isValid: Bool, errors: [String] = []) {
        self.isValid = isValid
        self.errors = errors
    }

    public static let valid = ValidationResult(isValid: true, errors: [])

    public static func invalid(_ errors: [String]) -> ValidationResult {
        ValidationResult(isValid: false, errors: errors)
    }

    public static func invalid(_ error: String) -> ValidationResult {
        ValidationResult(isValid: false, errors: [error])
    }
}
