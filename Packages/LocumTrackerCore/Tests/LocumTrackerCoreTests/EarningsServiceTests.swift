// LocumTracker
// Copyright (C) 2025 Dr Horst Herb
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import XCTest
@testable import LocumTrackerCore

final class EarningsServiceTests: XCTestCase {

    // MARK: - Daily Rate Tests

    func testCalculateDailyRateEarnings() {
        let earnings = EarningsService.calculateDailyRateEarnings(dailyRate: 400.0, daysWorked: 5)
        XCTAssertEqual(earnings, 2000.0)
    }

    func testCalculateDailyRateEarnings_ZeroDays() {
        let earnings = EarningsService.calculateDailyRateEarnings(dailyRate: 400.0, daysWorked: 0)
        XCTAssertEqual(earnings, 0.0)
    }

    // MARK: - Hourly Rate Tests

    func testCalculateHourlyEarnings() {
        let earnings = EarningsService.calculateHourlyEarnings(hourlyRate: 50.0, hoursWorked: 8.0)
        XCTAssertEqual(earnings, 400.0)
    }

    func testCalculateHourlyEarnings_PartialHours() {
        let earnings = EarningsService.calculateHourlyEarnings(hourlyRate: 60.0, hoursWorked: 7.5)
        XCTAssertEqual(earnings, 450.0)
    }

    // MARK: - On-Call Rate Tests

    func testCalculateOnCallEarnings_WithExplicitRate() {
        let earnings = EarningsService.calculateOnCallEarnings(
            baseHourlyRate: 50.0,
            onCallRate: 15.0,
            hours: 8.0
        )
        XCTAssertEqual(earnings, 120.0)
    }

    func testCalculateOnCallEarnings_WithDefaultPercentage() {
        // Default is 25% of base rate
        let earnings = EarningsService.calculateOnCallEarnings(
            baseHourlyRate: 100.0,
            onCallRate: nil,
            hours: 10.0
        )
        XCTAssertEqual(earnings, 250.0) // $25/hour * 10 hours
    }

    // MARK: - Call-Out Rate Tests

    func testCalculateCallOutEarnings() {
        let earnings = EarningsService.calculateCallOutEarnings(callOutRate: 50.0, occurrences: 3)
        XCTAssertEqual(earnings, 150.0)
    }

    func testCalculateCallOutEarnings_ZeroOccurrences() {
        let earnings = EarningsService.calculateCallOutEarnings(callOutRate: 50.0, occurrences: 0)
        XCTAssertEqual(earnings, 0.0)
    }

    // MARK: - Constants Tests

    func testDefaultOnCallPercentage() {
        XCTAssertEqual(EarningsService.defaultOnCallPercentage, 0.25)
    }

    func testDefaultCallOutPercentage() {
        XCTAssertEqual(EarningsService.defaultCallOutPercentage, 0.50)
    }
}
