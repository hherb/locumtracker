import XCTest
import CoreGraphics
import ImageIO
@testable import LocumTrackerOCR

final class OCREngineIntegrationTests: XCTestCase {

    var engine: OCREngine!

    override func setUp() async throws {
        engine = OCREngine(configuration: OCREngineConfiguration(
            maxImageSize: 960,
            detectionThreshold: 0.3,
            recognitionThreshold: 0.5,
            useCoreML: false  // Use CPU for consistent testing
        ))
        try await engine.initialize()
    }

    override func tearDown() {
        engine = nil
    }

    func testOCROnSampleReceipts() async throws {
        let sampleDir = "/Users/hherb/src/locumtracker/OCR_samples"
        let sampleFiles = ["IMG_4535.png", "IMG_9728.png", "IMG_9885.png"]

        for filename in sampleFiles {
            let imagePath = "\(sampleDir)/\(filename)"

            guard let image = loadImage(from: imagePath) else {
                XCTFail("Failed to load image: \(imagePath)")
                continue
            }

            let results = try await engine.recognizeText(in: image)

            // Verify we got some results
            XCTAssertFalse(results.isEmpty, "Should recognize some text in \(filename)")

            // Verify results have reasonable confidence
            for result in results {
                XCTAssertGreaterThanOrEqual(result.confidence, 0.5, "Confidence should be >= threshold")
                XCTAssertFalse(result.text.isEmpty, "Text should not be empty")
            }
        }
    }

    func testOCRExtractsKeyReceiptInfo() async throws {
        // Test that we can extract key receipt information
        let sampleDir = "/Users/hherb/src/locumtracker/OCR_samples"

        // Test United fuel receipt
        if let image = loadImage(from: "\(sampleDir)/IMG_4535.png") {
            let results = try await engine.recognizeText(in: image)
            let allText = results.map { $0.text }.joined(separator: " ").lowercased()

            // Should find key terms
            XCTAssertTrue(allText.contains("tax") || allText.contains("invoice"),
                          "Should find TAX INVOICE")
            XCTAssertTrue(allText.contains("51.98") || allText.contains("$51"),
                          "Should find total amount")
        }

        // Test Officeworks receipt
        if let image = loadImage(from: "\(sampleDir)/IMG_9728.png") {
            let results = try await engine.recognizeText(in: image)
            let allText = results.map { $0.text }.joined(separator: " ").lowercased()

            XCTAssertTrue(allText.contains("officeworks"),
                          "Should find store name")
            XCTAssertTrue(allText.contains("83") || allText.contains("$83"),
                          "Should find total amount")
        }

        // Test Stratford Fuels receipt
        if let image = loadImage(from: "\(sampleDir)/IMG_9885.png") {
            let results = try await engine.recognizeText(in: image)
            let allText = results.map { $0.text }.joined(separator: " ").lowercased()

            XCTAssertTrue(allText.contains("stratford") || allText.contains("fuels"),
                          "Should find store name")
        }
    }

    private func loadImage(from path: String) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return image
    }
}
