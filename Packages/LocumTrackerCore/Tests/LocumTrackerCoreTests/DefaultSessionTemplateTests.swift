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

final class DefaultSessionTemplateTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization() {
        let template = DefaultSessionTemplate(
            startHour: 8,
            startMinute: 30,
            endHour: 12,
            endMinute: 0,
            label: "Morning"
        )

        XCTAssertEqual(template.startHour, 8)
        XCTAssertEqual(template.startMinute, 30)
        XCTAssertEqual(template.endHour, 12)
        XCTAssertEqual(template.endMinute, 0)
        XCTAssertEqual(template.label, "Morning")
    }

    func testInitialization_ClampsInvalidHours() {
        let template = DefaultSessionTemplate(
            startHour: 25,
            startMinute: 0,
            endHour: -1,
            endMinute: 0
        )

        XCTAssertEqual(template.startHour, 23)
        XCTAssertEqual(template.endHour, 0)
    }

    func testInitialization_ClampsInvalidMinutes() {
        let template = DefaultSessionTemplate(
            startHour: 8,
            startMinute: 75,
            endHour: 12,
            endMinute: -10
        )

        XCTAssertEqual(template.startMinute, 59)
        XCTAssertEqual(template.endMinute, 0)
    }

    // MARK: - Duration Tests

    func testDurationHours_ValidSession() {
        let template = DefaultSessionTemplate(
            startHour: 8,
            startMinute: 0,
            endHour: 12,
            endMinute: 0
        )

        XCTAssertEqual(template.durationHours, 4.0)
    }

    func testDurationHours_WithMinutes() {
        let template = DefaultSessionTemplate(
            startHour: 8,
            startMinute: 30,
            endHour: 12,
            endMinute: 0
        )

        XCTAssertEqual(template.durationHours, 3.5)
    }

    func testDurationHours_EndBeforeStart_ReturnsZero() {
        let template = DefaultSessionTemplate(
            startHour: 14,
            startMinute: 0,
            endHour: 8,
            endMinute: 0
        )

        XCTAssertEqual(template.durationHours, 0)
    }

    // MARK: - Time Range Formatting Tests

    func testTimeRangeFormatted() {
        let template = DefaultSessionTemplate(
            startHour: 8,
            startMinute: 30,
            endHour: 17,
            endMinute: 0
        )

        XCTAssertEqual(template.timeRangeFormatted, "08:30 - 17:00")
    }

    func testTimeRangeFormatted_SingleDigitHours() {
        let template = DefaultSessionTemplate(
            startHour: 6,
            startMinute: 0,
            endHour: 9,
            endMinute: 30
        )

        XCTAssertEqual(template.timeRangeFormatted, "06:00 - 09:30")
    }

    // MARK: - Date Combination Tests

    func testStartDate_CombinesWithDate() {
        let template = DefaultSessionTemplate(
            startHour: 9,
            startMinute: 30,
            endHour: 12,
            endMinute: 0
        )

        let calendar = Calendar.current
        let testDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!

        let result = template.startDate(on: testDate)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)

        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 30)
    }

    func testEndDate_CombinesWithDate() {
        let template = DefaultSessionTemplate(
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 45
        )

        let calendar = Calendar.current
        let testDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!

        let result = template.endDate(on: testDate)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)

        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 17)
        XCTAssertEqual(components.minute, 45)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = DefaultSessionTemplate(
            startHour: 8,
            startMinute: 0,
            endHour: 12,
            endMinute: 30,
            label: "Morning Shift"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DefaultSessionTemplate.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.startHour, original.startHour)
        XCTAssertEqual(decoded.startMinute, original.startMinute)
        XCTAssertEqual(decoded.endHour, original.endHour)
        XCTAssertEqual(decoded.endMinute, original.endMinute)
        XCTAssertEqual(decoded.label, original.label)
    }

    func testEncodeDecodeArray() throws {
        let templates = [
            DefaultSessionTemplate.morningSession(),
            DefaultSessionTemplate.afternoonSession()
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(templates)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([DefaultSessionTemplate].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].label, "Morning")
        XCTAssertEqual(decoded[1].label, "Afternoon")
    }

    // MARK: - Equatable Tests

    func testEquatable_Equal() {
        let id = UUID()
        let template1 = DefaultSessionTemplate(
            id: id,
            startHour: 8,
            startMinute: 0,
            endHour: 12,
            endMinute: 0,
            label: "Morning"
        )
        let template2 = DefaultSessionTemplate(
            id: id,
            startHour: 8,
            startMinute: 0,
            endHour: 12,
            endMinute: 0,
            label: "Morning"
        )

        XCTAssertEqual(template1, template2)
    }

    func testEquatable_NotEqual() {
        let template1 = DefaultSessionTemplate(
            startHour: 8,
            startMinute: 0,
            endHour: 12,
            endMinute: 0
        )
        let template2 = DefaultSessionTemplate(
            startHour: 9,
            startMinute: 0,
            endHour: 12,
            endMinute: 0
        )

        XCTAssertNotEqual(template1, template2)
    }

    // MARK: - Convenience Initializer Tests

    func testMorningSession() {
        let template = DefaultSessionTemplate.morningSession()

        XCTAssertEqual(template.startHour, 8)
        XCTAssertEqual(template.startMinute, 0)
        XCTAssertEqual(template.endHour, 12)
        XCTAssertEqual(template.endMinute, 0)
        XCTAssertEqual(template.label, "Morning")
        XCTAssertEqual(template.durationHours, 4.0)
    }

    func testAfternoonSession() {
        let template = DefaultSessionTemplate.afternoonSession()

        XCTAssertEqual(template.startHour, 13)
        XCTAssertEqual(template.startMinute, 0)
        XCTAssertEqual(template.endHour, 17)
        XCTAssertEqual(template.endMinute, 0)
        XCTAssertEqual(template.label, "Afternoon")
        XCTAssertEqual(template.durationHours, 4.0)
    }
}
