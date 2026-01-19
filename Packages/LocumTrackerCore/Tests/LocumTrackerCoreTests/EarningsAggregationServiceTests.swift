import XCTest
@testable import LocumTrackerCore

final class EarningsAggregationServiceTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    // MARK: - EarningsPeriod.startDate Tests

    func testEarningsPeriod_Week_Returns7DaysAgo() {
        let reference = makeDate(year: 2026, month: 1, day: 15)
        let result = EarningsPeriod.week.startDate(from: reference)

        // Compare dates to the day
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: result), 2026)
        XCTAssertEqual(calendar.component(.month, from: result), 1)
        XCTAssertEqual(calendar.component(.day, from: result), 8)
    }

    func testEarningsPeriod_Month_Returns1MonthAgo() {
        let reference = makeDate(year: 2026, month: 3, day: 15)
        let result = EarningsPeriod.month.startDate(from: reference)

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: result), 2026)
        XCTAssertEqual(calendar.component(.month, from: result), 2)
        XCTAssertEqual(calendar.component(.day, from: result), 15)
    }

    func testEarningsPeriod_Quarter_Returns3MonthsAgo() {
        let reference = makeDate(year: 2026, month: 6, day: 15)
        let result = EarningsPeriod.quarter.startDate(from: reference)

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: result), 2026)
        XCTAssertEqual(calendar.component(.month, from: result), 3)
        XCTAssertEqual(calendar.component(.day, from: result), 15)
    }

    func testEarningsPeriod_Year_Returns1YearAgo() {
        let reference = makeDate(year: 2026, month: 6, day: 15)
        let result = EarningsPeriod.year.startDate(from: reference)

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: result), 2025)
        XCTAssertEqual(calendar.component(.month, from: result), 6)
        XCTAssertEqual(calendar.component(.day, from: result), 15)
    }

    func testEarningsPeriod_All_ReturnsDistantPast() {
        let result = EarningsPeriod.all.startDate()
        XCTAssertEqual(result, Date.distantPast)
    }

    func testEarningsPeriod_Month_CrossesYearBoundary() {
        let reference = makeDate(year: 2026, month: 1, day: 15)
        let result = EarningsPeriod.month.startDate(from: reference)

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: result), 2025)
        XCTAssertEqual(calendar.component(.month, from: result), 12)
    }

    // MARK: - Percentage Calculation Tests

    func testPercentage_ValidTotal() {
        XCTAssertEqual(EarningsAggregationService.percentage(earnings: 500, total: 1000), 50.0, accuracy: 0.001)
    }

    func testPercentage_ZeroTotal_ReturnsZero() {
        XCTAssertEqual(EarningsAggregationService.percentage(earnings: 500, total: 0), 0.0)
    }

    func testPercentage_FullAmount() {
        XCTAssertEqual(EarningsAggregationService.percentage(earnings: 1000, total: 1000), 100.0, accuracy: 0.001)
    }

    func testPercentage_SmallFraction() {
        XCTAssertEqual(EarningsAggregationService.percentage(earnings: 1, total: 1000), 0.1, accuracy: 0.001)
    }

    func testPercentage_LargerThanTotal() {
        // Edge case: earnings greater than total (shouldn't happen normally, but handle gracefully)
        XCTAssertEqual(EarningsAggregationService.percentage(earnings: 1500, total: 1000), 150.0, accuracy: 0.001)
    }

    // MARK: - Effective Hourly Rate Tests

    func testEffectiveHourlyRate_ValidHours() {
        XCTAssertEqual(EarningsAggregationService.effectiveHourlyRate(earnings: 800, hours: 8), 100.0, accuracy: 0.01)
    }

    func testEffectiveHourlyRate_ZeroHours_ReturnsZero() {
        XCTAssertEqual(EarningsAggregationService.effectiveHourlyRate(earnings: 800, hours: 0), 0.0)
    }

    func testEffectiveHourlyRate_FractionalHours() {
        XCTAssertEqual(EarningsAggregationService.effectiveHourlyRate(earnings: 150, hours: 1.5), 100.0, accuracy: 0.01)
    }

    func testEffectiveHourlyRate_TypicalDoctorRate() {
        // A doctor earning $1200 for 8 hours = $150/hr
        XCTAssertEqual(EarningsAggregationService.effectiveHourlyRate(earnings: 1200, hours: 8), 150.0, accuracy: 0.01)
    }

    // MARK: - Net Earnings Tests

    func testNetEarnings_Calculation() {
        XCTAssertEqual(EarningsAggregationService.netEarnings(total: 5000, expenses: 1200), 3800, accuracy: 0.01)
    }

    func testNetEarnings_ExpensesExceedEarnings_ReturnsNegative() {
        XCTAssertEqual(EarningsAggregationService.netEarnings(total: 1000, expenses: 1500), -500, accuracy: 0.01)
    }

    func testNetEarnings_ZeroExpenses() {
        XCTAssertEqual(EarningsAggregationService.netEarnings(total: 5000, expenses: 0), 5000, accuracy: 0.01)
    }

    func testNetEarnings_ZeroEarnings() {
        XCTAssertEqual(EarningsAggregationService.netEarnings(total: 0, expenses: 500), -500, accuracy: 0.01)
    }

    // MARK: - Sum Earnings Tests

    func testSumEarnings_MultipleValues() {
        let values = [100.0, 200.0, 300.0]
        XCTAssertEqual(EarningsAggregationService.sumEarnings(values), 600.0, accuracy: 0.01)
    }

    func testSumEarnings_EmptyArray() {
        let values: [Double] = []
        XCTAssertEqual(EarningsAggregationService.sumEarnings(values), 0.0)
    }

    func testSumEarnings_SingleValue() {
        let values = [500.0]
        XCTAssertEqual(EarningsAggregationService.sumEarnings(values), 500.0, accuracy: 0.01)
    }

    // MARK: - EarningsPeriod CaseIterable Tests

    func testEarningsPeriod_AllCases() {
        XCTAssertEqual(EarningsPeriod.allCases.count, 5)
        XCTAssertTrue(EarningsPeriod.allCases.contains(.week))
        XCTAssertTrue(EarningsPeriod.allCases.contains(.month))
        XCTAssertTrue(EarningsPeriod.allCases.contains(.quarter))
        XCTAssertTrue(EarningsPeriod.allCases.contains(.year))
        XCTAssertTrue(EarningsPeriod.allCases.contains(.all))
    }

    func testEarningsPeriod_RawValues() {
        XCTAssertEqual(EarningsPeriod.week.rawValue, "This Week")
        XCTAssertEqual(EarningsPeriod.month.rawValue, "This Month")
        XCTAssertEqual(EarningsPeriod.quarter.rawValue, "This Quarter")
        XCTAssertEqual(EarningsPeriod.year.rawValue, "This Year")
        XCTAssertEqual(EarningsPeriod.all.rawValue, "All Time")
    }
}
