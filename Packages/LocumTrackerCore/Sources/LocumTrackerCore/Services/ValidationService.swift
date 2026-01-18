import Foundation

/// Handles validation of data models and business rules
/// Ensures data integrity and compliance with business requirements
public struct ValidationService {
    
    // MARK: - Constants
    
    /// Minimum allowed MMM classification
    private static let minimumMMMClassification = 1
    
    /// Maximum allowed MMM classification
    private static let maximumMMMClassification = 7
    
    /// Minimum allowed rate for assignments
    private static let minimumAllowedRate = 0.0
    
    /// Maximum session duration (24 hours)
    private static let maximumSessionDurationSeconds: TimeInterval = 86400
    
    /// Minimum session duration (1 minute)
    private static let minimumSessionDurationSeconds: TimeInterval = 60
    
    /// Maximum allowed assignments per day
    private static let maximumAssignmentsPerDay = 10
    
    // MARK: - Location Validation
    
    /// Validates location data for completeness and correctness
    /// - Parameter location: Location to validate
    /// - Returns: Validation result with any issues found
    public static func validateLocation(_ location: Location) -> ValidationResult {
        var errors: [String] = []
        
        // Validate name
        if location.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Location name is required")
        }
        
        // Validate address
        if location.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Location address is required")
        }
        
        // Validate MMM classification
        if !isValidMMMClassification(location.mmmClassification) {
            errors.append("MMM classification must be between 1 and 7")
        }
        
        // Validate ASGS RA if provided
        if let asgsRA = location.asgsRA, asgsRA < 1 || asgsRA > 5 {
            errors.append("ASGS RA classification must be between 1 and 5")
        }
        
        // Validate coordinates if both provided
        if let latitude = location.latitude, let longitude = location.longitude {
            if latitude < -90 || latitude > 90 {
                errors.append("Latitude must be between -90 and 90 degrees")
            }
            if longitude < -180 || longitude > 180 {
                errors.append("Longitude must be between -180 and 180 degrees")
            }
        }
        
        // Validate effective dates
        if location.effectiveFrom > Date() {
            errors.append("Effective from date cannot be in the future")
        }
        
        if let effectiveTo = location.effectiveTo {
            if effectiveTo <= location.effectiveFrom {
                errors.append("Effective to date must be after effective from date")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    /// Validates MMM classification value
    /// - Parameter mmmClassification: MMM classification to validate
    /// - Returns: True if classification is valid
    public static func isValidMMMClassification(_ mmmClassification: Int) -> Bool {
        return mmmClassification >= minimumMMMClassification && mmmClassification <= maximumMMMClassification
    }
    
    // MARK: - Assignment Validation
    
    /// Validates assignment data for completeness and business rules
    /// - Parameter assignment: Assignment to validate
    /// - Returns: Validation result with any issues found
    public static func validateAssignment(_ assignment: Assignment) -> ValidationResult {
        var errors: [String] = []
        
        // Validate date range
        if assignment.startDate >= assignment.endDate {
            errors.append("Start date must be before end date")
        }
        
        if assignment.endDate < Date() {
            errors.append("End date cannot be in the past")
        }
        
        // Validate rate configuration
        switch assignment.rateStructure {
        case .dailyRate:
            if let dailyRate = assignment.dailyRate, dailyRate <= minimumAllowedRate {
                errors.append("Daily rate must be greater than 0")
            } else if assignment.dailyRate == nil {
                errors.append("Daily rate is required for daily rate assignments")
            }
            
        case .hourlyRate:
            if let hourlyRate = assignment.hourlyRate, hourlyRate <= minimumAllowedRate {
                errors.append("Hourly rate must be greater than 0")
            } else if assignment.hourlyRate == nil {
                errors.append("Hourly rate is required for hourly rate assignments")
            }
        }
        
        // Validate special rates if provided
        for specialRate in assignment.specialRates {
            if specialRate.multiplier < 0 {
                errors.append("Special rate multiplier must be positive")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Session Validation
    
    /// Validates session data for logical consistency
    /// - Parameter session: Session to validate
    /// - Returns: Validation result with any issues found
    public static func validateSession(_ session: Session) -> ValidationResult {
        var errors: [String] = []
        
        // Validate time logic
        if session.startTime >= session.endTime {
            errors.append("Start time must be before end time")
        }
        
        let duration = session.endTime.timeIntervalSince(session.startTime)
        
        if duration < minimumSessionDurationSeconds {
            errors.append("Session duration must be at least 1 minute")
        }
        
        if duration > maximumSessionDurationSeconds {
            errors.append("Session duration cannot exceed 24 hours")
        }
        
        // Validate MMM classification
        if !isValidMMMClassification(session.mmmClassification) {
            errors.append("MMM classification must be between 1 and 7")
        }
        
        // Validate travel time if provided
        if let travelTime = session.travelTime, travelTime < 0 {
            errors.append("Travel time cannot be negative")
        }
        
        // Validate that session is not in the distant future
        if session.startTime > Date().addingTimeInterval(86400 * 30) { // 30 days
            errors.append("Session start time cannot be more than 30 days in the future")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Daily Record Validation
    
    /// Validates daily record for data integrity
    /// - Parameter dailyRecord: DailyRecord to validate
    /// - Returns: Validation result with any issues found
    public static func validateDailyRecord(_ dailyRecord: DailyRecord) -> ValidationResult {
        var errors: [String] = []
        
        // Validate that at least one session exists
        if dailyRecord.sessions.isEmpty {
            errors.append("Daily record must have at least one session")
        }
        
        // Validate sessions don't overlap
        let sortedSessions = dailyRecord.sessions.sorted { $0.startTime < $1.startTime }
        for i in 1..<sortedSessions.count {
            let currentSession = sortedSessions[i]
            let previousSession = sortedSessions[i-1]
            
            if currentSession.startTime < previousSession.endTime {
                errors.append("Sessions cannot overlap")
            }
        }
        
        // Validate all sessions individually
        for session in dailyRecord.sessions {
            let sessionValidation = validateSession(session)
            if !sessionValidation.isValid {
                errors.append(contentsOf: sessionValidation.errors)
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Receipt Validation
    
    /// Validates receipt data for completeness
    /// - Parameter receipt: Receipt to validate
    /// - Returns: Validation result with any issues found
    public static func validateReceipt(_ receipt: Receipt) -> ValidationResult {
        var errors: [String] = []
        
        // Validate amount
        if receipt.amount < 0 {
            errors.append("Receipt amount cannot be negative")
        }
        
        // Validate description
        if receipt.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Receipt description is required")
        }
        
        // Validate date is not in the distant future
        if receipt.date > Date().addingTimeInterval(86400 * 30) { // 30 days
            errors.append("Receipt date cannot be more than 30 days in the future")
        }
        
        // Validate image data size if present
        if let imageData = receipt.imageData {
            let imageSizeMB = Double(imageData.count) / (1024 * 1024)
            if imageSizeMB > 20 { // Reasonable limit
                errors.append("Receipt image size cannot exceed 20MB")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Profile Validation
    
    /// Validates locum profile for completeness
    /// - Parameter profile: LocumProfile to validate
    /// - Returns: Validation result with any issues found
    public static func validateProfile(_ profile: LocumProfile) -> ValidationResult {
        var errors: [String] = []
        
        // Validate name fields
        if profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("First name is required")
        }
        
        if profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Last name is required")
        }
        
        // Validate email
        if !isValidEmail(profile.email) {
            errors.append("Valid email address is required")
        }
        
        // Validate ABN if provided
        if let abn = profile.abn, !abn.isEmpty {
            if !TaxService.validateABN(abn) {
                errors.append("Invalid Australian Business Number format")
            }
        }
        
        // Validate rates
        if profile.defaultDailyRate <= minimumAllowedRate {
            errors.append("Default daily rate must be greater than 0")
        }
        
        if profile.defaultHourlyRate <= minimumAllowedRate {
            errors.append("Default hourly rate must be greater than 0")
        }
        
        // Validate payment details
        let paymentValidation = validatePaymentDetails(profile.paymentDetails)
        if !paymentValidation.isValid {
            errors.append(contentsOf: paymentValidation.errors)
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    /// Validates payment details for completeness
    /// - Parameter paymentDetails: PaymentDetails to validate
    /// - Returns: Validation result with any issues found
    public static func validatePaymentDetails(_ paymentDetails: PaymentDetails) -> ValidationResult {
        var errors: [String] = []
        
        // Validate bank name
        if paymentDetails.bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Bank name is required")
        }
        
        // Validate account number
        if paymentDetails.accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Account number is required")
        }
        
        // Validate account holder name
        if paymentDetails.accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Account holder name is required")
        }
        
        // Validate BSB if provided
        if let bsbNumber = paymentDetails.bsbNumber, !bsbNumber.isEmpty {
            let cleanBSB = bsbNumber.replacingOccurrences(of: "-", with: "")
            if cleanBSB.count != 6 || !cleanBSB.allSatisfy(\.isNumber) {
                errors.append("BSB number must be 6 digits")
            }
        }
        
        // Validate PayPal email if provided
        if let paypalEmail = paymentDetails.paypalEmail, !paypalEmail.isEmpty {
            if !isValidEmail(paypalEmail) {
                errors.append("Valid PayPal email address is required")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Business Rule Validation
    
    /// Validates business rules for assignment creation
    /// - Parameters:
    ///   - assignments: Existing assignments for the period
    ///   - newAssignment: New assignment to validate
    /// - Returns: Validation result with any conflicts or issues
    public static func validateAssignmentCreation(
        _ newAssignment: Assignment,
        againstExisting assignments: [Assignment]
    ) -> ValidationResult {
        var errors: [String] = []
        
        // Check for overlapping assignments
        let overlappingAssignments = assignments.filter { assignment in
            dateRangesOverlap(
                newAssignment.startDate...newAssignment.endDate,
                assignment.startDate...assignment.endDate
            )
        }
        
        if !overlappingAssignments.isEmpty {
            errors.append("Assignment dates overlap with existing assignments")
        }
        
        // Validate not exceeding maximum assignments per day
        let assignmentDays = getDatesInRange(newAssignment.startDate...newAssignment.endDate)
        for date in assignmentDays {
            let assignmentsForDate = assignments.filter { assignment in
                assignment.dateRange.contains(date)
            }
            if assignmentsForDate.count >= maximumAssignmentsPerDay {
                errors.append("Cannot have more than \(maximumAssignmentsPerDay) assignments on the same day")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    /// Validates that an assignment can accommodate the requested sessions
    /// - Parameters:
    ///   - assignment: Assignment to validate against
    ///   - sessions: Sessions to validate
    /// - Returns: Validation result with any issues
    public static func validateSessionsForAssignment(
        _ sessions: [Session],
        for assignment: Assignment
    ) -> ValidationResult {
        var errors: [String] = []
        
        // Check that all sessions are within assignment date range
        for session in sessions {
            if !assignment.dateRange.contains(session.startTime) {
                errors.append("Session start time is outside assignment date range")
            }
            
            if !assignment.dateRange.contains(session.endTime) {
                errors.append("Session end time is outside assignment date range")
            }
        }
        
        // Check that sessions don't overlap
        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        for i in 1..<sortedSessions.count {
            let currentSession = sortedSessions[i]
            let previousSession = sortedSessions[i-1]
            
            if currentSession.startTime < previousSession.endTime {
                errors.append("Sessions cannot overlap within the same assignment")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Helper Methods
    
    /// Validates email address format
    /// - Parameter email: Email address to validate
    /// - Returns: True if email format is valid
    private static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    /// Checks if two date ranges overlap
    /// - Parameters:
    ///   - range1: First date range
    ///   - range2: Second date range
    /// - Returns: True if ranges overlap
    private static func dateRangesOverlap(_ range1: ClosedRange<Date>, _ range2: ClosedRange<Date>) -> Bool {
        return range1.overlaps(range2)
    }
    
    /// Gets all dates within a date range
    /// - Parameter dateRange: Date range to extract dates from
    /// - Returns: Array of dates in the range
    private static func getDatesInRange(_ dateRange: ClosedRange<Date>) -> [Date] {
        var dates: [Date] = []
        var currentDate = dateRange.lowerBound
        
        while currentDate <= dateRange.upperBound {
            dates.append(currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
}

// MARK: - Supporting Types

/// Result of validation operation
public struct ValidationResult {
    /// Whether the validation passed
    public let isValid: Bool
    
    /// Array of validation errors found
    public let errors: [String]
    
    /// Initialize validation result
    /// - Parameters:
    ///   - isValid: Whether validation passed
    ///   - errors: Array of error messages
    public init(isValid: Bool, errors: [String]) {
        self.isValid = isValid
        self.errors = errors
    }
    
    /// Returns first error message, or nil if valid
    public var firstError: String? {
        return errors.first
    }
    
    /// Returns formatted error message for display
    public var errorMessage: String {
        if isValid {
            return "Validation passed"
        } else {
            return errors.joined(separator: "; ")
        }
    }
}