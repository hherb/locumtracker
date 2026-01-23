import XCTest
@testable import LocumTrackerOCR

/// Tests for OCRConfiguration to ensure configuration values are valid.
final class OCRConfigurationTests: XCTestCase {

    // MARK: - Model File Names Tests

    func testModelFileNamesAreNotEmpty() {
        XCTAssertFalse(OCRConfiguration.ModelFiles.detectionModel.isEmpty)
        XCTAssertFalse(OCRConfiguration.ModelFiles.recognitionModel.isEmpty)
        XCTAssertFalse(OCRConfiguration.ModelFiles.characterDictionary.isEmpty)
        XCTAssertFalse(OCRConfiguration.ModelFiles.resourceDirectory.isEmpty)
    }

    func testModelFileNamesHaveCorrectExtensions() {
        XCTAssertTrue(
            OCRConfiguration.ModelFiles.detectionModel.hasSuffix(".onnx"),
            "Detection model should be an ONNX file"
        )
        XCTAssertTrue(
            OCRConfiguration.ModelFiles.recognitionModel.hasSuffix(".onnx"),
            "Recognition model should be an ONNX file"
        )
        XCTAssertTrue(
            OCRConfiguration.ModelFiles.characterDictionary.hasSuffix(".txt"),
            "Character dictionary should be a text file"
        )
    }

    // MARK: - Model URLs Tests

    func testModelURLsAreValid() {
        XCTAssertNotNil(URL(string: OCRConfiguration.ModelURLs.detectionModel))
        XCTAssertNotNil(URL(string: OCRConfiguration.ModelURLs.recognitionModel))
        XCTAssertNotNil(URL(string: OCRConfiguration.ModelURLs.characterDictionary))
    }

    func testModelURLsUseHTTPS() {
        XCTAssertTrue(
            OCRConfiguration.ModelURLs.detectionModel.hasPrefix("https://"),
            "Detection model URL should use HTTPS"
        )
        XCTAssertTrue(
            OCRConfiguration.ModelURLs.recognitionModel.hasPrefix("https://"),
            "Recognition model URL should use HTTPS"
        )
        XCTAssertTrue(
            OCRConfiguration.ModelURLs.characterDictionary.hasPrefix("https://"),
            "Character dictionary URL should use HTTPS"
        )
    }

    func testModelURLsPointToHuggingFace() {
        XCTAssertTrue(
            OCRConfiguration.ModelURLs.baseURL.contains("huggingface.co"),
            "Base URL should point to Hugging Face"
        )
    }

    // MARK: - Image Processing Tests

    func testImageDimensionLimitsAreValid() {
        XCTAssertGreaterThan(
            OCRConfiguration.ImageProcessing.maxInputDimension,
            OCRConfiguration.ImageProcessing.minInputDimension,
            "Max dimension should be greater than min dimension"
        )
        XCTAssertGreaterThan(
            OCRConfiguration.ImageProcessing.minInputDimension, 0,
            "Min dimension should be positive"
        )
    }

    func testNormalizationArraysHaveCorrectLength() {
        XCTAssertEqual(
            OCRConfiguration.ImageProcessing.normalizationMean.count, 3,
            "Normalization mean should have 3 values (RGB)"
        )
        XCTAssertEqual(
            OCRConfiguration.ImageProcessing.normalizationStd.count, 3,
            "Normalization std should have 3 values (RGB)"
        )
    }

    func testNormalizationValuesArePositive() {
        for value in OCRConfiguration.ImageProcessing.normalizationMean {
            XCTAssertGreaterThan(value, 0, "Normalization mean values should be positive")
        }
        for value in OCRConfiguration.ImageProcessing.normalizationStd {
            XCTAssertGreaterThan(value, 0, "Normalization std values should be positive")
        }
    }

    // MARK: - Detection Settings Tests

    func testDetectionThresholdsAreInValidRange() {
        XCTAssertGreaterThanOrEqual(OCRConfiguration.Detection.binaryThreshold, 0.0)
        XCTAssertLessThanOrEqual(OCRConfiguration.Detection.binaryThreshold, 1.0)
        XCTAssertGreaterThanOrEqual(OCRConfiguration.Detection.boxThreshold, 0.0)
        XCTAssertLessThanOrEqual(OCRConfiguration.Detection.boxThreshold, 1.0)
    }

    func testDetectionMaxCandidatesIsPositive() {
        XCTAssertGreaterThan(OCRConfiguration.Detection.maxCandidates, 0)
    }

    // MARK: - Recognition Settings Tests

    func testRecognitionInputDimensionsAreValid() {
        XCTAssertGreaterThan(OCRConfiguration.Recognition.inputHeight, 0)
        XCTAssertGreaterThan(OCRConfiguration.Recognition.maxInputWidth, 0)
    }

    func testRecognitionConfidenceThresholdIsInValidRange() {
        XCTAssertGreaterThanOrEqual(OCRConfiguration.Recognition.confidenceThreshold, 0.0)
        XCTAssertLessThanOrEqual(OCRConfiguration.Recognition.confidenceThreshold, 1.0)
    }

    // MARK: - Network Settings Tests

    func testNetworkRetrySettingsAreValid() {
        XCTAssertGreaterThan(OCRConfiguration.Network.maxRetryAttempts, 0)
        XCTAssertGreaterThan(OCRConfiguration.Network.retryBaseDelay, 0)
        XCTAssertGreaterThanOrEqual(
            OCRConfiguration.Network.retryMaxDelay,
            OCRConfiguration.Network.retryBaseDelay
        )
        XCTAssertGreaterThan(OCRConfiguration.Network.retryBackoffMultiplier, 1.0)
    }

    func testNetworkTimeoutsArePositive() {
        XCTAssertGreaterThan(OCRConfiguration.Network.requestTimeout, 0)
        XCTAssertGreaterThan(OCRConfiguration.Network.downloadTimeout, 0)
        XCTAssertGreaterThan(
            OCRConfiguration.Network.downloadTimeout,
            OCRConfiguration.Network.requestTimeout,
            "Download timeout should be greater than request timeout"
        )
    }

    // MARK: - Expected File Sizes Tests

    func testExpectedFileSizesArePositive() {
        XCTAssertGreaterThan(OCRConfiguration.ExpectedFileSizes.detectionModel, 0)
        XCTAssertGreaterThan(OCRConfiguration.ExpectedFileSizes.recognitionModel, 0)
        XCTAssertGreaterThan(OCRConfiguration.ExpectedFileSizes.characterDictionary, 0)
    }

    func testFileSizeToleranceIsValid() {
        XCTAssertGreaterThan(OCRConfiguration.ExpectedFileSizes.tolerancePercentage, 0.0)
        XCTAssertLessThanOrEqual(OCRConfiguration.ExpectedFileSizes.tolerancePercentage, 1.0)
    }
}
