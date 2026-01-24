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

final class LocationTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization_RequiredFieldsOnly() {
        let location = Location(
            name: "Test Hospital",
            address: "123 Main St",
            mmmClassification: 4
        )

        XCTAssertEqual(location.name, "Test Hospital")
        XCTAssertEqual(location.address, "123 Main St")
        XCTAssertEqual(location.mmmClassification, 4)
        XCTAssertNil(location.providerNumber)
        XCTAssertNil(location.phoneNumber)
        XCTAssertNil(location.notes)
        XCTAssertNil(location.defaultDailyRate)
        XCTAssertNil(location.defaultHourlyRate)
        XCTAssertNil(location.defaultOnCallRate)
        XCTAssertNil(location.defaultCallOutRate)
        XCTAssertTrue(location.defaultSessionTemplates.isEmpty)
    }

    func testInitialization_WithProviderNumber() {
        let location = Location(
            name: "Rural Clinic",
            address: "456 Country Rd",
            mmmClassification: 5,
            providerNumber: "1234567A"
        )

        XCTAssertEqual(location.providerNumber, "1234567A")
    }

    func testInitialization_WithPhoneNumber() {
        let location = Location(
            name: "Rural Clinic",
            address: "456 Country Rd",
            mmmClassification: 5,
            phoneNumber: "08 1234 5678"
        )

        XCTAssertEqual(location.phoneNumber, "08 1234 5678")
    }

    func testInitialization_WithNotes() {
        let location = Location(
            name: "Rural Clinic",
            address: "456 Country Rd",
            mmmClassification: 5,
            notes: "Park at rear entrance"
        )

        XCTAssertEqual(location.notes, "Park at rear entrance")
    }

    func testInitialization_WithAllOptionalFields() {
        let location = Location(
            name: "Complete Hospital",
            address: "789 Full St",
            mmmClassification: 6,
            providerNumber: "7654321B",
            phoneNumber: "02 9876 5432",
            notes: "Contact Dr Smith on arrival",
            defaultDailyRate: 1500.0,
            defaultHourlyRate: 150.0,
            defaultOnCallRate: 50.0,
            defaultCallOutRate: 75.0
        )

        XCTAssertEqual(location.name, "Complete Hospital")
        XCTAssertEqual(location.providerNumber, "7654321B")
        XCTAssertEqual(location.phoneNumber, "02 9876 5432")
        XCTAssertEqual(location.notes, "Contact Dr Smith on arrival")
        XCTAssertEqual(location.defaultDailyRate, 1500.0)
        XCTAssertEqual(location.defaultHourlyRate, 150.0)
        XCTAssertEqual(location.defaultOnCallRate, 50.0)
        XCTAssertEqual(location.defaultCallOutRate, 75.0)
    }

    // MARK: - Rural Subsidy Eligibility Tests

    func testIsRuralSubsidyEligible_MMM1_NotEligible() {
        let location = Location(name: "City", address: "CBD", mmmClassification: 1)
        XCTAssertFalse(location.isRuralSubsidyEligible)
    }

    func testIsRuralSubsidyEligible_MMM2_NotEligible() {
        let location = Location(name: "Regional", address: "Town", mmmClassification: 2)
        XCTAssertFalse(location.isRuralSubsidyEligible)
    }

    func testIsRuralSubsidyEligible_MMM3_Eligible() {
        let location = Location(name: "Large Rural", address: "Town", mmmClassification: 3)
        XCTAssertTrue(location.isRuralSubsidyEligible)
    }

    func testIsRuralSubsidyEligible_MMM7_Eligible() {
        let location = Location(name: "Very Remote", address: "Outback", mmmClassification: 7)
        XCTAssertTrue(location.isRuralSubsidyEligible)
    }

    // MARK: - Default Rates Tests

    func testHasDefaultRates_WithDailyRate() {
        let location = Location(
            name: "Test",
            address: "Address",
            mmmClassification: 4,
            defaultDailyRate: 1200.0
        )

        XCTAssertTrue(location.hasDefaultRates)
    }

    func testHasDefaultRates_WithHourlyRate() {
        let location = Location(
            name: "Test",
            address: "Address",
            mmmClassification: 4,
            defaultHourlyRate: 120.0
        )

        XCTAssertTrue(location.hasDefaultRates)
    }

    func testHasDefaultRates_NoRates() {
        let location = Location(
            name: "Test",
            address: "Address",
            mmmClassification: 4
        )

        XCTAssertFalse(location.hasDefaultRates)
    }

    // MARK: - Default Session Templates Tests

    func testDefaultSessionTemplates_Empty() {
        let location = Location(
            name: "Test",
            address: "Address",
            mmmClassification: 4
        )

        XCTAssertTrue(location.defaultSessionTemplates.isEmpty)
        XCTAssertFalse(location.hasDefaultSessionTemplates)
    }

    func testDefaultSessionTemplates_WithTemplates() {
        let templates = [
            DefaultSessionTemplate.morningSession(),
            DefaultSessionTemplate.afternoonSession()
        ]

        let location = Location(
            name: "Test",
            address: "Address",
            mmmClassification: 4,
            defaultSessionTemplates: templates
        )

        XCTAssertEqual(location.defaultSessionTemplates.count, 2)
        XCTAssertTrue(location.hasDefaultSessionTemplates)
        XCTAssertEqual(location.defaultSessionTemplates[0].label, "Morning")
        XCTAssertEqual(location.defaultSessionTemplates[1].label, "Afternoon")
    }

    func testDefaultSessionTemplates_SetAndGet() {
        let location = Location(
            name: "Test",
            address: "Address",
            mmmClassification: 4
        )

        let templates = [DefaultSessionTemplate.morningSession()]
        location.defaultSessionTemplates = templates

        XCTAssertEqual(location.defaultSessionTemplates.count, 1)
        XCTAssertEqual(location.defaultSessionTemplates[0].label, "Morning")
    }

    // MARK: - MMM Classification Description Tests

    func testMMMClassificationDescription() {
        let location = Location(name: "Test", address: "Address", mmmClassification: 5)
        XCTAssertEqual(location.mmmClassificationDescription, "MMM5 - Small Rural Town")
    }

    func testMMMClassificationDescription_InvalidValue() {
        let location = Location(name: "Test", address: "Address", mmmClassification: 99)
        XCTAssertEqual(location.mmmClassificationDescription, "Unknown")
    }
}
