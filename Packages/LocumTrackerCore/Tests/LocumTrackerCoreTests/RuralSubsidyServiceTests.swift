import XCTest
@testable import LocumTrackerCore

final class RuralSubsidyServiceTests: XCTestCase {

    // MARK: - Eligibility Tests

    func testIsEligible_MMM1And2_ReturnsFalse() {
        XCTAssertFalse(RuralSubsidyService.isEligible(mmmClassification: 1))
        XCTAssertFalse(RuralSubsidyService.isEligible(mmmClassification: 2))
    }

    func testIsEligible_MMM3To7_ReturnsTrue() {
        for mmm in 3...7 {
            XCTAssertTrue(RuralSubsidyService.isEligible(mmmClassification: mmm))
        }
    }

    // MARK: - Base Rate Tests

    func testGetBaseRate_ReturnsCorrectRates() {
        XCTAssertEqual(RuralSubsidyService.getBaseRate(for: 1), 0.0)
        XCTAssertEqual(RuralSubsidyService.getBaseRate(for: 2), 0.0)
        XCTAssertEqual(RuralSubsidyService.getBaseRate(for: 3), 0.0)
        XCTAssertEqual(RuralSubsidyService.getBaseRate(for: 4), 15.0)
        XCTAssertEqual(RuralSubsidyService.getBaseRate(for: 5), 25.0)
        XCTAssertEqual(RuralSubsidyService.getBaseRate(for: 6), 45.0)
        XCTAssertEqual(RuralSubsidyService.getBaseRate(for: 7), 65.0)
    }

    // MARK: - Subsidy Calculation Tests

    func testCalculateSubsidy_MMM4_Vocational_ReturnsCorrectAmount() {
        // 2 hours at MMM4 ($15/hour) vocational = $30
        let result = RuralSubsidyService.calculateSubsidy(
            durationSeconds: 7200, // 2 hours
            mmmClassification: 4,
            isVocational: true
        )

        XCTAssertTrue(result.eligible)
        XCTAssertEqual(result.sessionHours, 2.0, accuracy: 0.01)
        XCTAssertEqual(result.baseRate, 15.0)
        XCTAssertEqual(result.subsidyAmount, 30.0, accuracy: 0.01)
    }

    func testCalculateSubsidy_MMM7_NonVocational_Returns80Percent() {
        // 1 hour at MMM7 ($65/hour) non-vocational = $65 * 0.8 = $52
        let result = RuralSubsidyService.calculateSubsidy(
            durationSeconds: 3600,
            mmmClassification: 7,
            isVocational: false
        )

        XCTAssertTrue(result.eligible)
        XCTAssertEqual(result.subsidyAmount, 52.0, accuracy: 0.01)
    }

    func testCalculateSubsidy_MMM1_NotEligible() {
        let result = RuralSubsidyService.calculateSubsidy(
            durationSeconds: 3600,
            mmmClassification: 1,
            isVocational: true
        )

        XCTAssertFalse(result.eligible)
        XCTAssertEqual(result.subsidyAmount, 0.0)
    }

    // MARK: - Travel Time Tests

    func testCalculateSubsidy_TravelTimeUnder1Hour_NotCounted() {
        let result = RuralSubsidyService.calculateSubsidy(
            durationSeconds: 3600,
            mmmClassification: 5,
            isVocational: true,
            travelTimeSeconds: 1800 // 30 minutes - should not count
        )

        XCTAssertEqual(result.travelHours, 0.0)
        XCTAssertEqual(result.effectiveHours, 1.0, accuracy: 0.01)
    }

    func testCalculateSubsidy_TravelTimeOver1Hour_IsCounted() {
        // 1 hour work + 1.5 hours travel at MMM5 ($25/hour) = 2.5 hours * $25 = $62.50
        let result = RuralSubsidyService.calculateSubsidy(
            durationSeconds: 3600,
            mmmClassification: 5,
            isVocational: true,
            travelTimeSeconds: 5400 // 1.5 hours
        )

        XCTAssertEqual(result.travelHours, 1.5, accuracy: 0.01)
        XCTAssertEqual(result.effectiveHours, 2.5, accuracy: 0.01)
        XCTAssertEqual(result.subsidyAmount, 62.50, accuracy: 0.01)
    }

    // MARK: - Total Subsidy Calculation Tests

    func testCalculateTotalSubsidy_MultipleMMMs() {
        let hoursByMMM = [
            4: 10.0,  // 10 hours at $15 = $150
            5: 5.0,   // 5 hours at $25 = $125
            6: 2.0    // 2 hours at $45 = $90
        ]

        let total = RuralSubsidyService.calculateTotalSubsidy(
            hoursByMMM: hoursByMMM,
            isVocational: true
        )

        XCTAssertEqual(total, 365.0, accuracy: 0.01)
    }

    func testCalculateTotalSubsidy_NonVocational_Returns80Percent() {
        let hoursByMMM = [5: 10.0] // 10 hours at $25 = $250 vocational, $200 non-vocational

        let total = RuralSubsidyService.calculateTotalSubsidy(
            hoursByMMM: hoursByMMM,
            isVocational: false
        )

        XCTAssertEqual(total, 200.0, accuracy: 0.01)
    }
}
