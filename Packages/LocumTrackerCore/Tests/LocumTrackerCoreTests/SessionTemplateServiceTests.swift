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

final class SessionTemplateServiceTests: XCTestCase {

    // MARK: - Template Resolution Tests

    func testResolveTemplates_AssignmentTemplatesTakePriority() {
        let assignmentTemplates = [DefaultSessionTemplate.morningSession()]
        let locationTemplates = [DefaultSessionTemplate.afternoonSession()]

        let result = SessionTemplateService.resolveTemplates(
            assignmentTemplates: assignmentTemplates,
            locationTemplates: locationTemplates
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.startHour, 8) // Morning session starts at 8
    }

    func testResolveTemplates_FallsBackToLocationTemplates() {
        let result = SessionTemplateService.resolveTemplates(
            assignmentTemplates: [],
            locationTemplates: [DefaultSessionTemplate.afternoonSession()]
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.startHour, 13) // Afternoon session starts at 13
    }

    func testResolveTemplates_PrefersLocationWhenFlagSet() {
        let assignmentTemplates = [DefaultSessionTemplate.morningSession()]
        let locationTemplates = [DefaultSessionTemplate.afternoonSession()]

        let result = SessionTemplateService.resolveTemplates(
            assignmentTemplates: assignmentTemplates,
            locationTemplates: locationTemplates,
            preferLocationTemplates: true
        )

        XCTAssertEqual(result.first?.startHour, 13) // Afternoon from location
    }

    func testResolveTemplates_PrefersLocationFlag_NoLocationTemplates() {
        let assignmentTemplates = [DefaultSessionTemplate.morningSession()]

        let result = SessionTemplateService.resolveTemplates(
            assignmentTemplates: assignmentTemplates,
            locationTemplates: [],
            preferLocationTemplates: true
        )

        // Falls back to assignment templates when location has none
        XCTAssertEqual(result.first?.startHour, 8) // Morning from assignment
    }

    func testResolveTemplates_BothEmpty() {
        let result = SessionTemplateService.resolveTemplates(
            assignmentTemplates: [],
            locationTemplates: []
        )

        XCTAssertTrue(result.isEmpty)
    }

    func testResolveTemplates_MultipleAssignmentTemplates() {
        let assignmentTemplates = [
            DefaultSessionTemplate.morningSession(),
            DefaultSessionTemplate.afternoonSession()
        ]

        let result = SessionTemplateService.resolveTemplates(
            assignmentTemplates: assignmentTemplates,
            locationTemplates: []
        )

        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Template Source Tests

    func testResolveTemplateSource_Assignment() {
        let source = SessionTemplateService.resolveTemplateSource(
            assignmentTemplates: [DefaultSessionTemplate.morningSession()],
            locationTemplates: [DefaultSessionTemplate.afternoonSession()]
        )

        XCTAssertEqual(source, .assignment)
    }

    func testResolveTemplateSource_Location() {
        let source = SessionTemplateService.resolveTemplateSource(
            assignmentTemplates: [],
            locationTemplates: [DefaultSessionTemplate.afternoonSession()]
        )

        XCTAssertEqual(source, .location)
    }

    func testResolveTemplateSource_None() {
        let source = SessionTemplateService.resolveTemplateSource(
            assignmentTemplates: [],
            locationTemplates: []
        )

        XCTAssertEqual(source, .none)
    }

    func testResolveTemplateSource_PrefersLocationWhenFlagSet() {
        let source = SessionTemplateService.resolveTemplateSource(
            assignmentTemplates: [DefaultSessionTemplate.morningSession()],
            locationTemplates: [DefaultSessionTemplate.afternoonSession()],
            preferLocationTemplates: true
        )

        XCTAssertEqual(source, .location)
    }

    func testResolveTemplateSource_FallsBackToAssignment_WhenPrefersLocationButNone() {
        let source = SessionTemplateService.resolveTemplateSource(
            assignmentTemplates: [DefaultSessionTemplate.morningSession()],
            locationTemplates: [],
            preferLocationTemplates: true
        )

        XCTAssertEqual(source, .assignment)
    }
}
