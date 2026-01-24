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

    // MARK: - Daily Earnings Calculation Tests

    func testCalculateDailyEarnings_DailyRate_WithSessions() {
        // Daily rate: any session logged counts as full day
        let sessions: [(type: SessionType, durationHours: Double)] = [
            (.regular, 4.0),
            (.regular, 4.0)
        ]

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: .dailyRate,
            dailyRate: 1500.0,
            hourlyRate: nil,
            onCallRate: nil,
            callOutRate: nil,
            sessions: sessions
        )

        XCTAssertEqual(earnings, 1500.0, "Daily rate should be full amount regardless of session count")
    }

    func testCalculateDailyEarnings_DailyRate_SingleSession() {
        // Even a single session counts as full day for daily rate
        let sessions: [(type: SessionType, durationHours: Double)] = [
            (.regular, 2.0)
        ]

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: .dailyRate,
            dailyRate: 1500.0,
            hourlyRate: nil,
            onCallRate: nil,
            callOutRate: nil,
            sessions: sessions
        )

        XCTAssertEqual(earnings, 1500.0, "Single session should earn full daily rate")
    }

    func testCalculateDailyEarnings_DailyRate_NoSessions() {
        let sessions: [(type: SessionType, durationHours: Double)] = []

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: .dailyRate,
            dailyRate: 1500.0,
            hourlyRate: nil,
            onCallRate: nil,
            callOutRate: nil,
            sessions: sessions
        )

        XCTAssertEqual(earnings, 0.0, "No sessions should mean zero earnings")
    }

    func testCalculateDailyEarnings_HourlyRate_RegularSessions() {
        let sessions: [(type: SessionType, durationHours: Double)] = [
            (.regular, 4.0),
            (.regular, 4.0)
        ]

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: .hourlyRate,
            dailyRate: nil,
            hourlyRate: 150.0,
            onCallRate: nil,
            callOutRate: nil,
            sessions: sessions
        )

        XCTAssertEqual(earnings, 1200.0, "8 hours at $150/hour = $1200")
    }

    func testCalculateDailyEarnings_HourlyRate_MixedSessions() {
        let sessions: [(type: SessionType, durationHours: Double)] = [
            (.regular, 8.0),    // 8 * 150 = 1200
            (.onCall, 16.0)     // 16 * (150 * 0.25) = 600
        ]

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: .hourlyRate,
            dailyRate: nil,
            hourlyRate: 150.0,
            onCallRate: nil,     // Uses default 25%
            callOutRate: nil,
            sessions: sessions
        )

        XCTAssertEqual(earnings, 1800.0, "Regular (1200) + OnCall (600) = $1800")
    }

    func testCalculateDailyEarnings_HourlyRate_WithExplicitOnCallRate() {
        let sessions: [(type: SessionType, durationHours: Double)] = [
            (.onCall, 10.0)
        ]

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: .hourlyRate,
            dailyRate: nil,
            hourlyRate: 150.0,
            onCallRate: 50.0,    // Explicit $50/hour on-call rate
            callOutRate: nil,
            sessions: sessions
        )

        XCTAssertEqual(earnings, 500.0, "10 hours at $50/hour on-call = $500")
    }

    func testCalculateDailyEarnings_HourlyRate_CallOutWithExplicitRate() {
        let sessions: [(type: SessionType, durationHours: Double)] = [
            (.callOut, 2.0)
        ]

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: .hourlyRate,
            dailyRate: nil,
            hourlyRate: 150.0,
            onCallRate: nil,
            callOutRate: 200.0,   // Flat $200 per call-out
            sessions: sessions
        )

        XCTAssertEqual(earnings, 200.0, "Call-out should be flat rate")
    }

    func testCalculateDailyEarnings_HourlyRate_CallOutFallback() {
        // When no explicit call-out rate, use 50% of hourly * duration
        let sessions: [(type: SessionType, durationHours: Double)] = [
            (.callOut, 2.0)
        ]

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: .hourlyRate,
            dailyRate: nil,
            hourlyRate: 150.0,
            onCallRate: nil,
            callOutRate: nil,
            sessions: sessions
        )

        XCTAssertEqual(earnings, 150.0, "2 hours at 50% of $150 = $150")
    }

    func testCalculateDailyEarnings_HourlyRate_NoSessions() {
        let sessions: [(type: SessionType, durationHours: Double)] = []

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: .hourlyRate,
            dailyRate: nil,
            hourlyRate: 150.0,
            onCallRate: nil,
            callOutRate: nil,
            sessions: sessions
        )

        XCTAssertEqual(earnings, 0.0, "No sessions should mean zero earnings")
    }

    func testCalculateDailyEarnings_HourlyRate_MissingRate() {
        let sessions: [(type: SessionType, durationHours: Double)] = [
            (.regular, 8.0)
        ]

        let earnings = EarningsService.calculateDailyEarnings(
            rateStructure: .hourlyRate,
            dailyRate: nil,
            hourlyRate: nil,     // Missing hourly rate
            onCallRate: nil,
            callOutRate: nil,
            sessions: sessions
        )

        XCTAssertEqual(earnings, 0.0, "Missing hourly rate should result in zero earnings")
    }
}
