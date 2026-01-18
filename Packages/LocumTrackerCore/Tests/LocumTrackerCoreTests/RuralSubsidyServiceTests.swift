import XCTest
@testable import LocumTrackerCore

final class RuralSubsidyServiceTests: XCTestCase {
    
    // MARK: - Test Data
    
    private let oneHour = TimeInterval(3600)
    private let halfHour = TimeInterval(1800)
    private let twoHours = TimeInterval(7200)
    
    // MARK: - Session Subsidy Tests
    
    func testCalculateSessionSubsidy_MMM4Vocational() {
        // Given
        let duration = oneHour
        let mmmClassification = 4
        let isVocational = true
        
        // When
        let result = RuralSubsidyService.calculateSessionSubsidy(
            duration: duration,
            mmmClassification: mmmClassification,
            isVocational: isVocational
        )
        
        // Then
        XCTAssertEqual(result.sessionHours, 1.0)
        XCTAssertEqual(result.effectiveHours, 1.0)
        XCTAssertEqual(result.baseRate, 15.00)
        XCTAssertEqual(result.subsidyAmount, 15.00)
        XCTAssertTrue(result.eligible)
        XCTAssertTrue(result.isVocational)
        XCTAssertNil(result.reason)
    }
    
    func testCalculateSessionSubsidy_MMM5NonVocational() {
        // Given
        let duration = twoHours
        let mmmClassification = 5
        let isVocational = false
        
        // When
        let result = RuralSubsidyService.calculateSessionSubsidy(
            duration: duration,
            mmmClassification: mmmClassification,
            isVocational: isVocational
        )
        
        // Then
        XCTAssertEqual(result.sessionHours, 2.0)
        XCTAssertEqual(result.effectiveHours, 2.0)
        XCTAssertEqual(result.baseRate, 25.00)
        // 80% rate for non-vocational: $25 × 2 × 0.8 = $40
        XCTAssertEqual(result.subsidyAmount, 40.00)
        XCTAssertTrue(result.eligible)
        XCTAssertFalse(result.isVocational)
    }
    
    func testCalculateSessionSubsidy_MMM7WithTravelTime() {
        // Given
        let duration = oneHour
        let travelTime = TimeInterval(5400) // 1.5 hours
        let mmmClassification = 7
        let isVocational = true
        
        // When
        let result = RuralSubsidyService.calculateSessionSubsidy(
            duration: duration,
            mmmClassification: mmmClassification,
            isVocational: isVocational,
            travelTime: travelTime
        )
        
        // Then
        XCTAssertEqual(result.sessionHours, 1.0)
        XCTAssertEqual(result.travelHours, 1.5) // Travel time > 1 hour counts
        XCTAssertEqual(result.effectiveHours, 2.5) // Session + travel
        XCTAssertEqual(result.baseRate, 65.00)
        XCTAssertEqual(result.subsidyAmount, 162.50) // 2.5 hours × $65
        XCTAssertTrue(result.eligible)
    }
    
    func testCalculateSessionSubsidy_MMM1NotEligible() {
        // Given
        let duration = oneHour
        let mmmClassification = 1 // Metropolitan - not eligible
        let isVocational = true
        
        // When
        let result = RuralSubsidyService.calculateSessionSubsidy(
            duration: duration,
            mmmClassification: mmmClassification,
            isVocational: isVocational
        )
        
        // Then
        XCTAssertFalse(result.eligible)
        XCTAssertEqual(result.subsidyAmount, 0.00)
        XCTAssertEqual(result.reason, "MMM classification 1 is not eligible for rural subsidy")
    }
    
    func testCalculateSessionSubsidy_TravelTimeUnderThreshold() {
        // Given
        let duration = oneHour
        let travelTime = TimeInterval(1800) // 30 minutes - under threshold
        let mmmClassification = 6
        let isVocational = true
        
        // When
        let result = RuralSubsidyService.calculateSessionSubsidy(
            duration: duration,
            mmmClassification: mmmClassification,
            isVocational: isVocational,
            travelTime: travelTime
        )
        
        // Then
        XCTAssertEqual(result.sessionHours, 1.0)
        XCTAssertEqual(result.travelHours, 0.0) // Travel time < 1 hour doesn't count
        XCTAssertEqual(result.effectiveHours, 1.0)
        XCTAssertEqual(result.subsidyAmount, 45.00) // 1 hour × $45
    }
    
    // MARK: - Quarterly Progress Tests
    
    func testCalculateQuarterlyProgress_QuotaMet() {
        // Given
        let sessions = createTestSessions(hours: [8, 7, 10, 6, 12])
        let quarterDate = Date()
        
        // When
        let result = RuralSubsidyService.calculateQuarterlyProgress(
            sessions: sessions,
            quarterDate: quarterDate
        )
        
        // Then
        XCTAssertEqual(result.mmm3Hours, 15.0) // Two sessions
        XCTAssertEqual(result.mmm4Hours, 13.0) // One session
        XCTAssertEqual(result.mmm5Hours, 8.0)  // One session
        XCTAssertEqual(result.mmm6Hours, 6.0)  // One session
        XCTAssertEqual(result.mmm7Hours, 12.0) // One session
        XCTAssertEqual(result.totalHours, 54.0)
        XCTAssertEqual(result.targetHours, 40.0)
        XCTAssertEqual(result.progressPercentage, 135.0)
        XCTAssertTrue(result.quotaMet)
        XCTAssertEqual(result.remainingHours, 0.0)
    }
    
    func testCalculateQuarterlyProgress_QuotaNotMet() {
        // Given
        let sessions = createTestSessions(hours: [6, 4, 3, 2, 1])
        let quarterDate = Date()
        
        // When
        let result = RuralSubsidyService.calculateQuarterlyProgress(
            sessions: sessions,
            quarterDate: quarterDate
        )
        
        // Then
        XCTAssertEqual(result.totalHours, 16.0)
        XCTAssertEqual(result.progressPercentage, 40.0)
        XCTAssertFalse(result.quotaMet)
        XCTAssertEqual(result.remainingHours, 24.0)
    }
    
    func testCalculateQuarterlyProgress_ExcludesMMM1AndMMM2() {
        // Given
        let sessions = [
            createTestSession(hours: 8, mmmClassification: 1), // Should be excluded
            createTestSession(hours: 6, mmmClassification: 2), // Should be excluded
            createTestSession(hours: 5, mmmClassification: 3), // Should be included
            createTestSession(hours: 7, mmmClassification: 4)  // Should be included
        ]
        let quarterDate = Date()
        
        // When
        let result = RuralSubsidyService.calculateQuarterlyProgress(
            sessions: sessions,
            quarterDate: quarterDate
        )
        
        // Then
        XCTAssertEqual(result.totalHours, 12.0) // Only MMM3 and MMM4 should count
        XCTAssertEqual(result.progressPercentage, 30.0)
    }
    
    // MARK: - MMM Validation Tests
    
    func testIsValidMMMClassification_ValidClassifications() {
        // Given & When & Then
        XCTAssertTrue(RuralSubsidyService.isValidMMMClassification(1))
        XCTAssertTrue(RuralSubsidyService.isValidMMMClassification(3))
        XCTAssertTrue(RuralSubsidyService.isValidMMMClassification(7))
    }
    
    func testIsValidMMMClassification_InvalidClassifications() {
        // Given & When & Then
        XCTAssertFalse(RuralSubsidyService.isValidMMMClassification(0))
        XCTAssertFalse(RuralSubsidyService.isValidMMMClassification(8))
        XCTAssertFalse(RuralSubsidyService.isValidMMMClassification(-1))
    }
    
    func testGetBaseRateForMMM_AllClassifications() {
        // Given & When & Then
        XCTAssertEqual(RuralSubsidyService.getBaseRateForMMM(3), 0.00)
        XCTAssertEqual(RuralSubsidyService.getBaseRateForMMM(4), 15.00)
        XCTAssertEqual(RuralSubsidyService.getBaseRateForMMM(5), 25.00)
        XCTAssertEqual(RuralSubsidyService.getBaseRateForMMM(6), 45.00)
        XCTAssertEqual(RuralSubsidyService.getBaseRateForMMM(7), 65.00)
        XCTAssertEqual(RuralSubsidyService.getBaseRateForMMM(1), 0.00) // Not eligible
        XCTAssertEqual(RuralSubsidyService.getBaseRateForMMM(99), 0.00) // Invalid
    }
    
    // MARK: - Helper Methods
    
    private func createTestSession(hours: Double, mmmClassification: Int = 4) -> Session {
        let location = Location(
            id: UUID(),
            name: "Test Location",
            address: "Test Address",
            mmmClassification: mmmClassification
        )
        
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(TimeInterval(hours * 3600))
        
        return Session(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            location: location,
            sessionType: .regular,
            mmmClassification: mmmClassification
        )
    }
    
    private func createTestSessions(hours: [Double]) -> [Session] {
        let mmmClassifications = [3, 4, 5, 6, 7]
        return zip(hours, mmmClassifications).map { hours, mmm in
            createTestSession(hours: hours, mmmClassification: mmm)
        }
    }
}