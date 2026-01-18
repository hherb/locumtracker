import XCTest
@testable import LocumTrackerCore

final class EarningsServiceTests: XCTestCase {
    
    // MARK: - Test Data
    
    private let oneHour = TimeInterval(3600)
    private let halfHour = TimeInterval(1800)
    private let eightHours = TimeInterval(28800)
    private let standardRate = 50.0
    private let dailyRate = 400.0
    private let onCallRate = 12.5
    private let callOutRate = 25.0
    
    // MARK: - Daily Earnings Tests
    
    func testCalculateDailyEarnings_DailyRateAssignment() {
        // Given
        let assignment = createTestAssignment(rateStructure: .dailyRate, dailyRate: dailyRate)
        let session = createTestSession(duration: oneHour, sessionType: .regular)
        let dailyRecord = DailyRecord(
            id: UUID(),
            assignmentId: assignment.id,
            date: Date(),
            sessions: [session]
        )
        
        // When
        let result = EarningsService.calculateDailyEarnings(dailyRecord: dailyRecord, assignment: assignment)
        
        // Then
        XCTAssertEqual(result.totalHours, 1.0)
        XCTAssertEqual(result.regularEarnings, dailyRate) // Daily rate regardless of hours
        XCTAssertEqual(result.totalEarnings, dailyRate)
        XCTAssertEqual(result.sessionEarnings.count, 1)
        XCTAssertEqual(result.sessionEarnings.first?.amount, dailyRate)
    }
    
    func testCalculateDailyEarnings_HourlyRateAssignment() {
        // Given
        let assignment = createTestAssignment(rateStructure: .hourlyRate, hourlyRate: standardRate)
        let session = createTestSession(duration: oneHour, sessionType: .regular)
        let dailyRecord = DailyRecord(
            id: UUID(),
            assignmentId: assignment.id,
            date: Date(),
            sessions: [session]
        )
        
        // When
        let result = EarningsService.calculateDailyEarnings(dailyRecord: dailyRecord, assignment: assignment)
        
        // Then
        XCTAssertEqual(result.totalHours, 1.0)
        XCTAssertEqual(result.regularEarnings, standardRate) // 1 hour × $50
        XCTAssertEqual(result.totalEarnings, standardRate)
        XCTAssertEqual(result.sessionEarnings.first?.rate, standardRate)
    }
    
    func testCalculateDailyEarnings_MultipleSessions() {
        // Given
        let assignment = createTestAssignment(rateStructure: .hourlyRate, hourlyRate: standardRate)
        let session1 = createTestSession(duration: oneHour, sessionType: .regular)
        let session2 = createTestSession(duration: halfHour, sessionType: .onCall)
        let dailyRecord = DailyRecord(
            id: UUID(),
            assignmentId: assignment.id,
            date: Date(),
            sessions: [session1, session2]
        )
        
        // When
        let result = EarningsService.calculateDailyEarnings(dailyRecord: dailyRecord, assignment: assignment)
        
        // Then
        XCTAssertEqual(result.totalHours, 1.5) // 1 hour + 0.5 hours
        XCTAssertEqual(result.regularEarnings, 56.25) // 1×$50 + 0.5×$12.5
        XCTAssertEqual(result.sessionEarnings.count, 2)
    }
    
    func testCalculateDailyEarnings_WithSubsidy() {
        // Given
        let assignment = createTestAssignment(rateStructure: .hourlyRate, hourlyRate: standardRate)
        let session = createTestSession(duration: oneHour, mmmClassification: 5)
        session.subsidyAmount = 25.0 // MMM5 subsidy
        let dailyRecord = DailyRecord(
            id: UUID(),
            assignmentId: assignment.id,
            date: Date(),
            sessions: [session]
        )
        
        // When
        let result = EarningsService.calculateDailyEarnings(dailyRecord: dailyRecord, assignment: assignment)
        
        // Then
        XCTAssertEqual(result.totalHours, 1.0)
        XCTAssertEqual(result.regularEarnings, standardRate)
        XCTAssertEqual(result.subsidyEarnings, 25.0)
        XCTAssertEqual(result.totalEarnings, 75.0) // $50 + $25
    }
    
    // MARK: - Session Earnings Tests
    
    func testCalculateSessionEarnings_RegularSession() {
        // Given
        let assignment = createTestAssignment(rateStructure: .hourlyRate, hourlyRate: standardRate)
        let session = createTestSession(duration: oneHour, sessionType: .regular)
        
        // When
        let result = EarningsService.calculateSessionEarnings(session: session, assignment: assignment)
        
        // Then
        XCTAssertEqual(result.rate, standardRate)
        XCTAssertEqual(result.hours, 1.0)
        XCTAssertEqual(result.amount, standardRate)
        XCTAssertEqual(result.sessionType, .regular)
    }
    
    func testCalculateSessionEarnings_OnCallSession() {
        // Given
        let assignment = createTestAssignment(rateStructure: .hourlyRate, hourlyRate: standardRate, onCallRate: onCallRate)
        let session = createTestSession(duration: oneHour, sessionType: .onCall)
        
        // When
        let result = EarningsService.calculateSessionEarnings(session: session, assignment: assignment)
        
        // Then
        XCTAssertEqual(result.rate, onCallRate)
        XCTAssertEqual(result.hours, 1.0)
        XCTAssertEqual(result.amount, onCallRate)
        XCTAssertEqual(result.sessionType, .onCall)
    }
    
    func testCalculateSessionEarnings_CallOutSession() {
        // Given
        let assignment = createTestAssignment(rateStructure: .hourlyRate, hourlyRate: standardRate, callOutRate: callOutRate)
        let session = createTestSession(duration: oneHour, sessionType: .callOut)
        
        // When
        let result = EarningsService.calculateSessionEarnings(session: session, assignment: assignment)
        
        // Then
        XCTAssertEqual(result.rate, callOutRate)
        XCTAssertEqual(result.hours, 1.0)
        XCTAssertEqual(result.amount, callOutRate)
        XCTAssertEqual(result.sessionType, .callOut)
    }
    
    func testCalculateSessionEarnings_DefaultOnCallRate() {
        // Given
        let assignment = createTestAssignment(rateStructure: .hourlyRate, hourlyRate: standardRate)
        // No explicit on-call rate provided
        let session = createTestSession(duration: oneHour, sessionType: .onCall)
        
        // When
        let result = EarningsService.calculateSessionEarnings(session: session, assignment: assignment)
        
        // Then
        // Should use default 25% of base rate: $50 × 0.25 = $12.50
        XCTAssertEqual(result.rate, 12.50, accuracy: 0.01)
        XCTAssertEqual(result.amount, 12.50, accuracy: 0.01)
    }
    
    // MARK: - Assignment Earnings Tests
    
    func testCalculateAssignmentEarnings_MultipleDailyRecords() {
        // Given
        let assignment = createTestAssignment(rateStructure: .dailyRate, dailyRate: dailyRate)
        let dailyRecord1 = DailyRecord(
            id: UUID(),
            assignmentId: assignment.id,
            date: Date(),
            sessions: [createTestSession(duration: oneHour)]
        )
        let dailyRecord2 = DailyRecord(
            id: UUID(),
            assignmentId: assignment.id,
            date: Date().addingTimeInterval(86400), // Next day
            sessions: [createTestSession(duration: halfHour)]
        )
        
        // When
        let result = EarningsService.calculateAssignmentEarnings(
            assignment: assignment,
            dailyRecords: [dailyRecord1, dailyRecord2]
        )
        
        // Then
        XCTAssertEqual(result.totalHours, 1.5)
        XCTAssertEqual(result.regularEarnings, 800.0) // 2 days × $400
        XCTAssertEqual(result.dailyRecords.count, 2)
    }
    
    // MARK: - Projected Earnings Tests
    
    func testCalculateProjectedEarnings_DailyRate() {
        // Given
        let rateStructure = RateStructure.dailyRate
        let expectedHours = 8.0
        let numberOfDays = 5
        
        // When
        let result = EarningsService.calculateProjectedEarnings(
            rateStructure: rateStructure,
            dailyRate: dailyRate,
            hourlyRate: nil,
            expectedHours: expectedHours,
            numberOfDays: numberOfDays
        )
        
        // Then
        XCTAssertEqual(result.rateStructure, .dailyRate)
        XCTAssertEqual(result.dailyRate, dailyRate)
        XCTAssertEqual(result.numberOfDays, numberOfDays)
        XCTAssertEqual(result.regularEarnings, 2000.0) // 5 days × $400
        XCTAssertEqual(result.expectedEarningsPerDay, 400.0)
        XCTAssertEqual(result.expectedEarningsPerHour, 100.0) // $400 ÷ 4 hours = $100/hour
    }
    
    func testCalculateProjectedEarnings_HourlyRate() {
        // Given
        let rateStructure = RateStructure.hourlyRate
        let expectedHours = 8.0
        let numberOfDays = 5
        
        // When
        let result = EarningsService.calculateProjectedEarnings(
            rateStructure: rateStructure,
            dailyRate: nil,
            hourlyRate: standardRate,
            expectedHours: expectedHours,
            numberOfDays: numberOfDays
        )
        
        // Then
        XCTAssertEqual(result.rateStructure, .hourlyRate)
        XCTAssertEqual(result.hourlyRate, standardRate)
        XCTAssertEqual(result.regularEarnings, 2000.0) // 5 days × 8 hours × $50
        XCTAssertEqual(result.expectedEarningsPerDay, 400.0)
        XCTAssertEqual(result.expectedEarningsPerHour, 50.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestAssignment(
        rateStructure: RateStructure,
        dailyRate: Double? = nil,
        hourlyRate: Double? = nil,
        onCallRate: Double? = nil,
        callOutRate: Double? = nil
    ) -> Assignment {
        
        let location = Location(
            id: UUID(),
            name: "Test Location",
            address: "123 Test St",
            mmmClassification: 4
        )
        
        return Assignment(
            id: UUID(),
            baseLocation: location,
            rateStructure: rateStructure,
            dailyRate: dailyRate,
            hourlyRate: hourlyRate,
            onCallRate: onCallRate,
            callOutRate: callOutRate,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7) // 1 week
        )
    }
    
    private func createTestSession(
        duration: TimeInterval,
        sessionType: SessionType = .regular,
        mmmClassification: Int = 4
    ) -> Session {
        
        let location = Location(
            id: UUID(),
            name: "Test Location",
            address: "123 Test St",
            mmmClassification: mmmClassification
        )
        
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(duration)
        
        let session = Session(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            location: location,
            sessionType: sessionType,
            mmmClassification: mmmClassification
        )
        
        // Set subsidy amount based on MMM classification
        if mmmClassification >= 3 {
            session.subsidyAmount = RuralSubsidyService.getBaseRateForMMM(mmmClassification)
        }
        
        return session
    }
}