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

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// High-level service for extracting receipt data from images.
///
/// This service manages the OCR engine lifecycle and provides a simple
/// interface for extracting structured receipt data from images.
///
/// ## Usage
/// ```swift
/// let service = ReceiptOCRService.shared
/// try await service.initialize()
///
/// if let cgImage = uiImage.cgImage {
///     let data = try await service.extractReceiptData(from: cgImage)
///     print("Total: $\(data.totalAmount ?? 0)")
/// }
/// ```
@MainActor
public final class ReceiptOCRService {

    /// Shared singleton instance.
    public static let shared = ReceiptOCRService()

    /// The underlying OCR engine.
    private let engine: OCREngine

    /// Whether the engine has been initialized.
    public private(set) var isInitialized = false

    /// Whether initialization is in progress.
    public private(set) var isInitializing = false

    /// Error from last initialization attempt, if any.
    public private(set) var initializationError: Error?

    private init() {
        self.engine = OCREngine(configuration: OCREngineConfiguration(
            maxImageSize: 960,
            detectionThreshold: 0.3,
            recognitionThreshold: 0.5,
            useCoreML: true
        ))
    }

    /// Initializes the OCR engine.
    ///
    /// Call this once at app startup or before first use.
    /// Safe to call multiple times - subsequent calls are no-ops if already initialized.
    ///
    /// - Throws: `OCRError` if initialization fails.
    public func initialize() async throws {
        guard !isInitialized && !isInitializing else { return }

        isInitializing = true
        initializationError = nil

        do {
            try await engine.initialize()
            isInitialized = true
            isInitializing = false
        } catch {
            isInitializing = false
            initializationError = error
            throw error
        }
    }

    /// Extracts receipt data from a CGImage.
    ///
    /// - Parameter image: The receipt image to process.
    /// - Returns: Extracted receipt data with merchant, amounts, and date.
    /// - Throws: `OCRError` if processing fails.
    public func extractReceiptData(from image: CGImage) async throws -> ReceiptData {
        if !isInitialized {
            try await initialize()
        }

        let ocrResults = try await engine.recognizeText(in: image)
        return ReceiptDataExtractor.extract(from: ocrResults)
    }

    #if canImport(UIKit)
    /// Extracts receipt data from image data (JPEG/PNG).
    ///
    /// - Parameter imageData: The image data to process.
    /// - Returns: Extracted receipt data, or nil if image data is invalid.
    /// - Throws: `OCRError` if processing fails.
    public func extractReceiptData(from imageData: Data) async throws -> ReceiptData? {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            return nil
        }
        return try await extractReceiptData(from: cgImage)
    }

    /// Extracts receipt data from a UIImage.
    ///
    /// - Parameter image: The UIImage to process.
    /// - Returns: Extracted receipt data, or nil if image cannot be converted.
    /// - Throws: `OCRError` if processing fails.
    public func extractReceiptData(from image: UIImage) async throws -> ReceiptData? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        return try await extractReceiptData(from: cgImage)
    }
    #endif

    /// Gets the raw OCR text from an image without parsing.
    ///
    /// Useful for debugging or when custom parsing is needed.
    ///
    /// - Parameter image: The image to process.
    /// - Returns: Array of OCR results with text and bounding boxes.
    /// - Throws: `OCRError` if processing fails.
    public func recognizeText(in image: CGImage) async throws -> [OCRResult] {
        if !isInitialized {
            try await initialize()
        }
        return try await engine.recognizeText(in: image)
    }
}

/// State for tracking OCR import progress in the UI.
public enum OCRImportState: Equatable, Sendable {
    /// No import in progress.
    case idle

    /// Initializing the OCR engine.
    case initializing

    /// Processing the image.
    case processing

    /// Import completed successfully.
    case completed(ReceiptData)

    /// Import failed with an error.
    case failed(String)

    public static func == (lhs: OCRImportState, rhs: OCRImportState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.initializing, .initializing), (.processing, .processing):
            return true
        case (.completed(let a), .completed(let b)):
            return a.rawText == b.rawText
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }

    /// Whether an import is currently in progress.
    public var isLoading: Bool {
        switch self {
        case .initializing, .processing:
            return true
        default:
            return false
        }
    }

    /// A user-friendly status message.
    public var statusMessage: String {
        switch self {
        case .idle:
            return ""
        case .initializing:
            return "Preparing OCR engine..."
        case .processing:
            return "Reading receipt..."
        case .completed:
            return "Import complete"
        case .failed(let message):
            return "Import failed: \(message)"
        }
    }
}
