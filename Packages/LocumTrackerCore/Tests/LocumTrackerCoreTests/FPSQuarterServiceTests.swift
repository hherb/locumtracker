import XCTest
@testable import LocumTrackerCore

final class FPSQuarterServiceTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    // MARK: - Quarter String Tests

    func testQuarterString_January_ReturnsQ1() {
        let date = makeDate(year: 2026, month: 1, day: 15)
        XCTAssertEqual(FPSQuarterService.quarterString(for: date), "2026 Q1")
    }

    func testQuarterString_February_ReturnsQ1() {
        let date = makeDate(year: 2026, month: 2, day: 28)
        XCTAssertEqual(FPSQuarterService.quarterString(for: date), "2026 Q1")
    }

    func testQuarterString_March_ReturnsQ1() {
        let date = makeDate(year: 2026, month: 3, day: 31)
        XCTAssertEqual(FPSQuarterService.quarterString(for: date), "2026 Q1")
    }

    func testQuarterString_April_ReturnsQ2() {
        let date = makeDate(year: 2026, month: 4, day: 1)
        XCTAssertEqual(FPSQuarterService.quarterString(for: date), "2026 Q2")
    }

    func testQuarterString_July_ReturnsQ3() {
        let date = makeDate(year: 2026, month: 7, day: 15)
        XCTAssertEqual(FPSQuarterService.quarterString(for: date), "2026 Q3")
    }

    func testQuarterString_December_ReturnsQ4() {
        let date = makeDate(year: 2026, month: 12, day: 31)
        XCTAssertEqual(FPSQuarterService.quarterString(for: date), "2026 Q4")
    }

    // MARK: - Quarter Identifier Tests

    func testQuarterIdentifier_Format() {
        let date = makeDate(year: 2026, month: 4, day: 1)
        XCTAssertEqual(FPSQuarterService.quarterIdentifier(for: date), "2026-Q2")
    }

    func testQuarterIdentifier_AllQuarters() {
        XCTAssertEqual(FPSQuarterService.quarterIdentifier(for: makeDate(year: 2026, month: 1, day: 1)), "2026-Q1")
        XCTAssertEqual(FPSQuarterService.quarterIdentifier(for: makeDate(year: 2026, month: 4, day: 1)), "2026-Q2")
        XCTAssertEqual(FPSQuarterService.quarterIdentifier(for: makeDate(year: 2026, month: 7, day: 1)), "2026-Q3")
        XCTAssertEqual(FPSQuarterService.quarterIdentifier(for: makeDate(year: 2026, month: 10, day: 1)), "2026-Q4")
    }

    // MARK: - Quarter Number Tests

    func testQuarterNumber_Q1Months() {
        XCTAssertEqual(FPSQuarterService.quarterNumber(for: makeDate(year: 2026, month: 1, day: 1)), 1)
        XCTAssertEqual(FPSQuarterService.quarterNumber(for: makeDate(year: 2026, month: 2, day: 15)), 1)
        XCTAssertEqual(FPSQuarterService.quarterNumber(for: makeDate(year: 2026, month: 3, day: 31)), 1)
    }

    func testQuarterNumber_Q4Months() {
        XCTAssertEqual(FPSQuarterService.quarterNumber(for: makeDate(year: 2026, month: 10, day: 1)), 4)
        XCTAssertEqual(FPSQuarterService.quarterNumber(for: makeDate(year: 2026, month: 11, day: 15)), 4)
        XCTAssertEqual(FPSQuarterService.quarterNumber(for: makeDate(year: 2026, month: 12, day: 31)), 4)
    }

    // MARK: - Days Remaining Tests

    func testDaysRemaining_StartOfQuarter() {
        let quarterStart = makeDate(year: 2026, month: 1, day: 1)
        let remaining = FPSQuarterService.daysRemaining(from: quarterStart)
        // Q1 has 90 days (31+28+31), so 89 remaining on day 1
        XCTAssertTrue(remaining > 80 && remaining <= 90)
    }

    func testDaysRemaining_MidQuarter() {
        let midQuarter = makeDate(year: 2026, month: 2, day: 15)
        let remaining = FPSQuarterService.daysRemaining(from: midQuarter)
        // About 44 days left (rest of Feb + March)
        XCTAssertTrue(remaining > 40 && remaining < 50)
    }

    func testDaysRemaining_EndOfQuarter_ReturnsLowValue() {
        let nearEnd = makeDate(year: 2026, month: 3, day: 30)
        let remaining = FPSQuarterService.daysRemaining(from: nearEnd)
        XCTAssertTrue(remaining <= 2)
    }

    // MARK: - Session Counting Tests

    func testCountSessions_SingleSessionPerDay() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 2)
        let day3 = makeDate(year: 2026, month: 1, day: 3)

        let sessionsPerDay = [day1: 1, day2: 1, day3: 1]
        XCTAssertEqual(FPSQuarterService.countSessions(sessionsPerDay), 3)
    }

    func testCountSessions_TwoSessionsPerDay() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 2)

        let sessionsPerDay = [day1: 2, day2: 2]
        XCTAssertEqual(FPSQuarterService.countSessions(sessionsPerDay), 4)
    }

    func testCountSessions_ThreeSessionsOnSameDay_CapsAtTwo() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)

        let sessionsPerDay = [day1: 3]
        XCTAssertEqual(FPSQuarterService.countSessions(sessionsPerDay), 2)
    }

    func testCountSessions_MixedSessionCounts() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 2)
        let day3 = makeDate(year: 2026, month: 1, day: 3)

        // 4 sessions on day 1 (capped to 2), 1 on day 2, 2 on day 3
        let sessionsPerDay = [day1: 4, day2: 1, day3: 2]
        XCTAssertEqual(FPSQuarterService.countSessions(sessionsPerDay), 5)
    }

    func testCountSessions_EmptyDictionary() {
        let sessionsPerDay: [Date: Int] = [:]
        XCTAssertEqual(FPSQuarterService.countSessions(sessionsPerDay), 0)
    }

    // MARK: - Days Exceeding Limit Tests

    func testDaysExceedingLimit_AllValid() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 2)

        let sessionsPerDay = [day1: 2, day2: 1]
        XCTAssertEqual(FPSQuarterService.daysExceedingLimit(sessionsPerDay), 0)
    }

    func testDaysExceedingLimit_OneDayWith3Sessions() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 2)

        let sessionsPerDay = [day1: 3, day2: 1]
        XCTAssertEqual(FPSQuarterService.daysExceedingLimit(sessionsPerDay), 1)
    }

    func testDaysExceedingLimit_MultipleDaysExceeding() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 2)
        let day3 = makeDate(year: 2026, month: 1, day: 3)

        let sessionsPerDay = [day1: 5, day2: 3, day3: 2]
        XCTAssertEqual(FPSQuarterService.daysExceedingLimit(sessionsPerDay), 2)
    }

    // MARK: - Predominant MMM Tests

    func testPredominantMMM_SingleClassification() {
        let counts = [5: 10]
        XCTAssertEqual(FPSQuarterService.predominantMMM(from: counts), 5)
    }

    func testPredominantMMM_MultipleClassifications() {
        let counts = [5: 10, 6: 3, 7: 5]
        XCTAssertEqual(FPSQuarterService.predominantMMM(from: counts), 5)
    }

    func testPredominantMMM_EmptyCounts_ReturnsZero() {
        let counts: [Int: Int] = [:]
        XCTAssertEqual(FPSQuarterService.predominantMMM(from: counts), 0)
    }

    func testPredominantMMM_TiedCounts_ReturnsOne() {
        // When tied, behavior depends on dictionary iteration order
        let counts = [5: 10, 6: 10]
        let result = FPSQuarterService.predominantMMM(from: counts)
        XCTAssertTrue(result == 5 || result == 6)
    }

    // MARK: - Progress Percentage Tests

    func testProgressPercentage_ZeroSessions() {
        XCTAssertEqual(FPSQuarterService.progressPercentage(sessions: 0), 0.0)
    }

    func testProgressPercentage_HalfwayTo21() {
        // 10.5 sessions = 50%, but we use integers so 10 ~ 47.6% and 11 ~ 52.4%
        XCTAssertEqual(FPSQuarterService.progressPercentage(sessions: 10), 10.0 / 21.0 * 100, accuracy: 0.1)
    }

    func testProgressPercentage_ExactlyAt21() {
        XCTAssertEqual(FPSQuarterService.progressPercentage(sessions: 21), 100.0)
    }

    func testProgressPercentage_Over21_CappedAt100() {
        XCTAssertEqual(FPSQuarterService.progressPercentage(sessions: 50), 100.0)
    }

    func testProgressPercentage_Over104_StillCappedAt100() {
        XCTAssertEqual(FPSQuarterService.progressPercentage(sessions: 104), 100.0)
    }

    // MARK: - Progress Color Tests

    func testProgressColorName_QuotaMet_ReturnsGreen() {
        XCTAssertEqual(FPSQuarterService.progressColorName(percentage: 100, quotaMet: true), "green")
    }

    func testProgressColorName_QuotaMetOverride() {
        // Even if percentage is low (shouldn't happen in practice), quotaMet wins
        XCTAssertEqual(FPSQuarterService.progressColorName(percentage: 50, quotaMet: true), "green")
    }

    func testProgressColorName_75Percent_ReturnsBlue() {
        XCTAssertEqual(FPSQuarterService.progressColorName(percentage: 75, quotaMet: false), "blue")
    }

    func testProgressColorName_80Percent_ReturnsBlue() {
        XCTAssertEqual(FPSQuarterService.progressColorName(percentage: 80, quotaMet: false), "blue")
    }

    func testProgressColorName_50Percent_ReturnsOrange() {
        XCTAssertEqual(FPSQuarterService.progressColorName(percentage: 50, quotaMet: false), "orange")
    }

    func testProgressColorName_74Percent_ReturnsOrange() {
        XCTAssertEqual(FPSQuarterService.progressColorName(percentage: 74, quotaMet: false), "orange")
    }

    func testProgressColorName_49Percent_ReturnsRed() {
        XCTAssertEqual(FPSQuarterService.progressColorName(percentage: 49, quotaMet: false), "red")
    }

    func testProgressColorName_ZeroPercent_ReturnsRed() {
        XCTAssertEqual(FPSQuarterService.progressColorName(percentage: 0, quotaMet: false), "red")
    }

    // MARK: - Quarter Start Date Tests

    func testQuarterStartDate_MidQuarter_ReturnsFirstDay() {
        let midQ1 = makeDate(year: 2026, month: 2, day: 15)
        let start = FPSQuarterService.quarterStartDate(for: midQ1)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: start)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
    }

    func testQuarterStartDate_FirstDayOfQuarter_ReturnsSameDay() {
        let firstQ2 = makeDate(year: 2026, month: 4, day: 1)
        let start = FPSQuarterService.quarterStartDate(for: firstQ2)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: start)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 1)
    }

    // MARK: - Count Sessions For Quarter Tests

    func testCountSessionsForQuarter_UnderCap() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 2)

        let sessionsPerDay = [day1: 2, day2: 2]
        XCTAssertEqual(FPSQuarterService.countSessionsForQuarter(sessionsPerDay), 4)
    }

    func testCountSessionsForQuarter_AppliesBothCaps() {
        // Create 60 days with 3 sessions each = 180 raw, 120 after daily cap, 104 after quarterly cap
        var sessionsPerDay: [Date: Int] = [:]
        for i in 0..<60 {
            let day = makeDate(year: 2026, month: 1, day: 1).addingTimeInterval(Double(i) * 86400)
            sessionsPerDay[day] = 3
        }

        // 60 days * 2 per day max = 120, then capped at 104
        XCTAssertEqual(FPSQuarterService.countSessionsForQuarter(sessionsPerDay), 104)
    }
}
