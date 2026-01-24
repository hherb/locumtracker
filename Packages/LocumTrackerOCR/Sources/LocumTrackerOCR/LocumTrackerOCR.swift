/// LocumTrackerOCR - On-device OCR for receipt text extraction
///
/// This module provides OCR capabilities using PaddleOCR models via ONNX Runtime.
/// It supports both iOS and macOS platforms with CoreML acceleration on Apple Neural Engine.
///
/// ## Features
/// - Text detection and recognition from receipt images
/// - Structured data extraction (merchant, amount, date, items)
/// - Fully offline operation with bundled models
///
/// ## Usage
/// ```swift
/// let engine = try OCREngine()
/// let result = try await engine.recognizeText(in: image)
/// let receiptData = ReceiptDataExtractor.extract(from: result)
/// ```

import Foundation

/// Module version information
public enum LocumTrackerOCRInfo {
    /// The current version of the LocumTrackerOCR module.
    public static let version = "1.0.0"

    /// The PaddleOCR model version used for OCR.
    public static let modelVersion = "PP-OCRv4"

    /// Indicates whether the module is using English-only models.
    public static let isEnglishOnly = true
}
