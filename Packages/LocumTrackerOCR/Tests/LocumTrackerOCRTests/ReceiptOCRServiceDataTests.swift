import XCTest
import ImageIO
@testable import LocumTrackerOCR

/// Tests for extracting receipt data from encoded image bytes, the entry point
/// used by the app on both iOS and macOS.
final class ReceiptOCRServiceDataTests: XCTestCase {

    private let sampleDir = "/Users/hherb/src/locumtracker/OCR_samples"

    func testUndecodableDataReturnsNil() async throws {
        let garbage = Data("not an image".utf8)
        let result = try await ReceiptOCRService.shared.extractReceiptData(from: garbage)
        XCTAssertNil(result)
    }

    func testEmptyDataReturnsNil() async throws {
        let result = try await ReceiptOCRService.shared.extractReceiptData(from: Data())
        XCTAssertNil(result)
    }

    func testPNGDataMatchesCGImageExtraction() async throws {
        let url = URL(fileURLWithPath: "\(sampleDir)/IMG_4535.png")
        let data = try Data(contentsOf: url)
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let cgImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))

        let fromData = try await ReceiptOCRService.shared.extractReceiptData(from: data)
        let fromImage = try await ReceiptOCRService.shared.extractReceiptData(from: cgImage)

        let receipt = try XCTUnwrap(fromData, "PNG data should decode and be processed")
        XCTAssertEqual(receipt.merchant, fromImage.merchant)
        XCTAssertEqual(receipt.totalAmount, fromImage.totalAmount)
        XCTAssertEqual(receipt.date, fromImage.date)
    }
}
