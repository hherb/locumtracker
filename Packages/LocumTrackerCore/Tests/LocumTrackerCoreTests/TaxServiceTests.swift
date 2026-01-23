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

final class TaxServiceTests: XCTestCase {

    // MARK: - GST Calculation Tests

    func testCalculateGST_WhenGSTRegistered_ReturnsCorrectGST() {
        let result = TaxService.calculateGST(amount: 100.0, isGSTRegistered: true)

        XCTAssertEqual(result.amount, 100.0)
        XCTAssertEqual(result.gstAmount, 10.0, accuracy: 0.01)
        XCTAssertEqual(result.totalIncludingGST, 110.0, accuracy: 0.01)
        XCTAssertTrue(result.isGSTRegistered)
    }

    func testCalculateGST_WhenNotGSTRegistered_ReturnsZeroGST() {
        let result = TaxService.calculateGST(amount: 100.0, isGSTRegistered: false)

        XCTAssertEqual(result.amount, 100.0)
        XCTAssertEqual(result.gstAmount, 0.0)
        XCTAssertEqual(result.totalIncludingGST, 100.0)
        XCTAssertFalse(result.isGSTRegistered)
    }

    func testExtractGST_ReturnsCorrectComponent() {
        // $110 inclusive = $10 GST
        let gst = TaxService.extractGST(from: 110.0)
        XCTAssertEqual(gst, 10.0, accuracy: 0.01)
    }

    // MARK: - ABN Validation Tests

    func testValidateABN_WithValidABNs_ReturnsTrue() {
        // Known valid ABNs from ATO examples
        let validABNs = [
            "51 824 753 556",
            "51824753556",
            "83 914 571 673",
        ]

        for abn in validABNs {
            XCTAssertTrue(TaxService.validateABN(abn), "ABN \(abn) should be valid")
        }
    }

    func testValidateABN_WithInvalidABNs_ReturnsFalse() {
        let invalidABNs = [
            "",                      // Empty
            "12345",                 // Too short
            "123456789012",          // Too long
            "11111111111",           // Invalid checksum
            "00000000000",           // All zeros
            "ABC12345678",           // Contains letters
        ]

        for abn in invalidABNs {
            XCTAssertFalse(TaxService.validateABN(abn), "ABN \(abn) should be invalid")
        }
    }

    func testFormatABN_ReturnsFormattedString() {
        let formatted = TaxService.formatABN("51824753556")
        XCTAssertEqual(formatted, "51 824 753 556")
    }

    func testFormatABN_WithInvalidLength_ReturnsOriginal() {
        let result = TaxService.formatABN("12345")
        XCTAssertEqual(result, "12345")
    }

    // MARK: - Customer ABN Threshold Tests

    func testRequiresCustomerABN_AboveThreshold_ReturnsTrue() {
        XCTAssertTrue(TaxService.requiresCustomerABN(100.0))
        XCTAssertTrue(TaxService.requiresCustomerABN(82.50))
    }

    func testRequiresCustomerABN_BelowThreshold_ReturnsFalse() {
        XCTAssertFalse(TaxService.requiresCustomerABN(82.49))
        XCTAssertFalse(TaxService.requiresCustomerABN(50.0))
    }
}
