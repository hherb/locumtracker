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

final class ProviderLocationTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization_RequiredFieldsOnly() {
        let location = ProviderLocation(
            name: "Main Street Clinic",
            providerNumber: "1234567A"
        )

        XCTAssertEqual(location.name, "Main Street Clinic")
        XCTAssertEqual(location.providerNumber, "1234567A")
        XCTAssertNil(location.address)
        XCTAssertNil(location.phone)
        XCTAssertNil(location.notes)
    }

    func testInitialization_AllFields() {
        let location = ProviderLocation(
            name: "Main Street Clinic",
            providerNumber: "1234567A",
            address: "123 Main St, Brisbane QLD 4000",
            phone: "07 1234 5678",
            notes: "Near the hospital"
        )

        XCTAssertEqual(location.name, "Main Street Clinic")
        XCTAssertEqual(location.providerNumber, "1234567A")
        XCTAssertEqual(location.address, "123 Main St, Brisbane QLD 4000")
        XCTAssertEqual(location.phone, "07 1234 5678")
        XCTAssertEqual(location.notes, "Near the hospital")
    }

    // MARK: - Display Name Tests

    func testDisplayName() {
        let location = ProviderLocation(
            name: "Suburban Medical",
            providerNumber: "9876543B"
        )

        XCTAssertEqual(location.displayName, "Suburban Medical (9876543B)")
    }

    // MARK: - Has Field Tests

    func testHasAddress_WithAddress() {
        let location = ProviderLocation(
            name: "Clinic",
            providerNumber: "1234567A",
            address: "123 Test St"
        )

        XCTAssertTrue(location.hasAddress)
    }

    func testHasAddress_WithNilAddress() {
        let location = ProviderLocation(
            name: "Clinic",
            providerNumber: "1234567A",
            address: nil
        )

        XCTAssertFalse(location.hasAddress)
    }

    func testHasAddress_WithEmptyAddress() {
        let location = ProviderLocation(
            name: "Clinic",
            providerNumber: "1234567A",
            address: "   "
        )

        XCTAssertFalse(location.hasAddress)
    }

    func testHasPhone_WithPhone() {
        let location = ProviderLocation(
            name: "Clinic",
            providerNumber: "1234567A",
            phone: "07 1234 5678"
        )

        XCTAssertTrue(location.hasPhone)
    }

    func testHasPhone_WithNilPhone() {
        let location = ProviderLocation(
            name: "Clinic",
            providerNumber: "1234567A",
            phone: nil
        )

        XCTAssertFalse(location.hasPhone)
    }

    func testHasPhone_WithEmptyPhone() {
        let location = ProviderLocation(
            name: "Clinic",
            providerNumber: "1234567A",
            phone: ""
        )

        XCTAssertFalse(location.hasPhone)
    }

    func testHasNotes_WithNotes() {
        let location = ProviderLocation(
            name: "Clinic",
            providerNumber: "1234567A",
            notes: "Some notes"
        )

        XCTAssertTrue(location.hasNotes)
    }

    func testHasNotes_WithNilNotes() {
        let location = ProviderLocation(
            name: "Clinic",
            providerNumber: "1234567A",
            notes: nil
        )

        XCTAssertFalse(location.hasNotes)
    }

    func testHasNotes_WithWhitespaceOnlyNotes() {
        let location = ProviderLocation(
            name: "Clinic",
            providerNumber: "1234567A",
            notes: "\n\t  "
        )

        XCTAssertFalse(location.hasNotes)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = ProviderLocation(
            name: "Test Clinic",
            providerNumber: "1234567A",
            address: "123 Test St",
            phone: "07 1234 5678",
            notes: "Test notes"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProviderLocation.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.providerNumber, original.providerNumber)
        XCTAssertEqual(decoded.address, original.address)
        XCTAssertEqual(decoded.phone, original.phone)
        XCTAssertEqual(decoded.notes, original.notes)
    }

    func testEncodeDecode_MinimalFields() throws {
        let original = ProviderLocation(
            name: "Test Clinic",
            providerNumber: "1234567A"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProviderLocation.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.providerNumber, original.providerNumber)
        XCTAssertNil(decoded.address)
        XCTAssertNil(decoded.phone)
        XCTAssertNil(decoded.notes)
    }

    func testEncodeDecodeArray() throws {
        let locations = [
            ProviderLocation(name: "Clinic A", providerNumber: "1111111A"),
            ProviderLocation(name: "Clinic B", providerNumber: "2222222B"),
            ProviderLocation(name: "Clinic C", providerNumber: "3333333C")
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(locations)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([ProviderLocation].self, from: data)

        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].name, "Clinic A")
        XCTAssertEqual(decoded[1].name, "Clinic B")
        XCTAssertEqual(decoded[2].name, "Clinic C")
    }

    // MARK: - Equatable Tests

    func testEquatable_Equal() {
        let id = UUID()
        let location1 = ProviderLocation(
            id: id,
            name: "Test Clinic",
            providerNumber: "1234567A",
            address: "123 Test St"
        )
        let location2 = ProviderLocation(
            id: id,
            name: "Test Clinic",
            providerNumber: "1234567A",
            address: "123 Test St"
        )

        XCTAssertEqual(location1, location2)
    }

    func testEquatable_NotEqual_DifferentId() {
        let location1 = ProviderLocation(
            name: "Test Clinic",
            providerNumber: "1234567A"
        )
        let location2 = ProviderLocation(
            name: "Test Clinic",
            providerNumber: "1234567A"
        )

        XCTAssertNotEqual(location1, location2)
    }

    func testEquatable_NotEqual_DifferentName() {
        let id = UUID()
        let location1 = ProviderLocation(
            id: id,
            name: "Clinic A",
            providerNumber: "1234567A"
        )
        let location2 = ProviderLocation(
            id: id,
            name: "Clinic B",
            providerNumber: "1234567A"
        )

        XCTAssertNotEqual(location1, location2)
    }

    // MARK: - Identifiable Tests

    func testIdentifiable() {
        let location = ProviderLocation(
            name: "Test Clinic",
            providerNumber: "1234567A"
        )

        XCTAssertNotNil(location.id)
    }

    func testIdentifiable_CustomId() {
        let customId = UUID()
        let location = ProviderLocation(
            id: customId,
            name: "Test Clinic",
            providerNumber: "1234567A"
        )

        XCTAssertEqual(location.id, customId)
    }
}
