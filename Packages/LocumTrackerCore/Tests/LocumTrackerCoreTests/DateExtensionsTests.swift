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

final class DateExtensionsTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    // MARK: - TimeInterval.formattedDuration Tests

    func testFormattedDuration_HoursAndMinutes() {
        let interval: TimeInterval = 5400 // 1h 30m
        XCTAssertEqual(interval.formattedDuration, "1h 30m")
    }

    func testFormattedDuration_HoursOnly() {
        let interval: TimeInterval = 7200 // 2h
        XCTAssertEqual(interval.formattedDuration, "2h")
    }

    func testFormattedDuration_MinutesOnly() {
        let interval: TimeInterval = 1800 // 30m
        XCTAssertEqual(interval.formattedDuration, "30m")
    }

    func testFormattedDuration_ZeroSeconds() {
        let interval: TimeInterval = 0
        XCTAssertEqual(interval.formattedDuration, "0m")
    }

    func testFormattedDuration_LargeValue() {
        let interval: TimeInterval = 36000 // 10h
        XCTAssertEqual(interval.formattedDuration, "10h")
    }

    // MARK: - TimeInterval.travelTimeFormatted Tests

    func testTravelTimeFormatted_UnderHour() {
        let interval: TimeInterval = 2700 // 45m
        XCTAssertEqual(interval.travelTimeFormatted, "45m travel")
    }

    func testTravelTimeFormatted_ExactHour() {
        let interval: TimeInterval = 3600 // 1h
        XCTAssertEqual(interval.travelTimeFormatted, "1h travel")
    }

    func testTravelTimeFormatted_HoursAndMinutes() {
        let interval: TimeInterval = 5400 // 1h 30m
        XCTAssertEqual(interval.travelTimeFormatted, "1h 30m travel")
    }

    func testTravelTimeFormatted_TwoHours() {
        let interval: TimeInterval = 7200 // 2h
        XCTAssertEqual(interval.travelTimeFormatted, "2h travel")
    }

    func testTravelTimeFormatted_ShortTrip() {
        let interval: TimeInterval = 900 // 15m
        XCTAssertEqual(interval.travelTimeFormatted, "15m travel")
    }

    // MARK: - TimeInterval.hours Tests

    func testHours_WholeNumber() {
        let interval: TimeInterval = 7200 // 2h
        XCTAssertEqual(interval.hours, 2.0, accuracy: 0.001)
    }

    func testHours_Fractional() {
        let interval: TimeInterval = 5400 // 1.5h
        XCTAssertEqual(interval.hours, 1.5, accuracy: 0.001)
    }

    // MARK: - TimeInterval.minutes Tests

    func testMinutes_WholeHour() {
        let interval: TimeInterval = 3600 // 60m
        XCTAssertEqual(interval.minutes, 60)
    }

    func testMinutes_PartialMinute() {
        let interval: TimeInterval = 90 // 1.5m, rounds to 1
        XCTAssertEqual(interval.minutes, 1)
    }

    // MARK: - Date.daysInRange Tests

    func testDaysInRange_SameDay() {
        let date = makeDate(year: 2026, month: 1, day: 1)
        XCTAssertEqual(Date.daysInRange(from: date, to: date), 1)
    }

    func testDaysInRange_TwoDays() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 2)
        XCTAssertEqual(Date.daysInRange(from: start, to: end), 2)
    }

    func testDaysInRange_OneWeek() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 7)
        XCTAssertEqual(Date.daysInRange(from: start, to: end), 7)
    }

    func testDaysInRange_CrossMonth() {
        let start = makeDate(year: 2026, month: 1, day: 28)
        let end = makeDate(year: 2026, month: 2, day: 3)
        XCTAssertEqual(Date.daysInRange(from: start, to: end), 7) // 28,29,30,31,1,2,3
    }

    // MARK: - Date.rangeText Tests

    func testRangeText_ContainsSeparator() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 15)
        let result = Date.rangeText(from: start, to: end)
        XCTAssertTrue(result.contains(" - "))
    }

    func testRangeText_ContainsBothDates() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 15)
        let result = Date.rangeText(from: start, to: end)
        // Result format depends on locale, but should contain year
        XCTAssertTrue(result.contains("2026") || result.contains("26"))
    }

    // MARK: - Date.durationText Tests

    func testDurationText_SingleDay() {
        let date = makeDate(year: 2026, month: 1, day: 1)
        XCTAssertEqual(Date.durationText(from: date, to: date), "1 day")
    }

    func testDurationText_MultipleDays() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 5)
        XCTAssertEqual(Date.durationText(from: start, to: end), "5 days")
    }

    func testDurationText_TwoDays() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 2)
        XCTAssertEqual(Date.durationText(from: start, to: end), "2 days")
    }

    // MARK: - Date Properties Tests

    func testStartOfDay() {
        let date = makeDate(year: 2026, month: 1, day: 15)
        let startOfDay = date.startOfDay
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: startOfDay)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testIsWeekend_Saturday() {
        // January 3, 2026 is a Saturday
        let saturday = makeDate(year: 2026, month: 1, day: 3)
        XCTAssertTrue(saturday.isWeekend)
    }

    func testIsWeekend_Sunday() {
        // January 4, 2026 is a Sunday
        let sunday = makeDate(year: 2026, month: 1, day: 4)
        XCTAssertTrue(sunday.isWeekend)
    }

    func testIsWeekend_Weekday() {
        // January 5, 2026 is a Monday
        let monday = makeDate(year: 2026, month: 1, day: 5)
        XCTAssertFalse(monday.isWeekend)
    }

    func testStartOfQuarter_Q1() {
        let midQ1 = makeDate(year: 2026, month: 2, day: 15)
        let start = midQ1.startOfQuarter
        let components = Calendar.current.dateComponents([.year, .month, .day], from: start)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
    }

    func testStartOfQuarter_Q4() {
        let midQ4 = makeDate(year: 2026, month: 11, day: 15)
        let start = midQ4.startOfQuarter
        let components = Calendar.current.dateComponents([.year, .month, .day], from: start)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 10)
        XCTAssertEqual(components.day, 1)
    }

    func testAddingDays() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let result = start.addingDays(5)
        let components = Calendar.current.dateComponents([.day], from: result)
        XCTAssertEqual(components.day, 6)
    }
}
