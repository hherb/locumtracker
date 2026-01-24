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

/// Result of text recognition for a single text region.
///
/// Each OCRResult represents one detected and recognized text block
/// from the input image, including its location and confidence score.
public struct OCRResult: Identifiable, Sendable {
    /// Unique identifier for this result.
    public let id: UUID

    /// The recognized text content.
    public let text: String

    /// Bounding box in original image coordinates.
    ///
    /// The coordinate system matches CGImage conventions:
    /// - Origin at top-left
    /// - X increases to the right
    /// - Y increases downward
    public let boundingBox: CGRect

    /// Recognition confidence score between 0 and 1.
    ///
    /// Higher values indicate more confident recognition.
    /// Typical thresholds:
    /// - Above 0.8: High confidence
    /// - 0.5-0.8: Medium confidence
    /// - Below 0.5: Low confidence (may contain errors)
    public let confidence: Float

    /// Creates a new OCR result.
    ///
    /// - Parameters:
    ///   - text: The recognized text.
    ///   - boundingBox: The bounding box in image coordinates.
    ///   - confidence: Recognition confidence (0-1).
    ///   - id: Optional UUID, auto-generated if not provided.
    public init(text: String, boundingBox: CGRect, confidence: Float, id: UUID = UUID()) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

extension OCRResult: Equatable {
    public static func == (lhs: OCRResult, rhs: OCRResult) -> Bool {
        lhs.id == rhs.id
    }
}

extension OCRResult: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension OCRResult: CustomStringConvertible {
    public var description: String {
        "OCRResult(text: \"\(text)\", confidence: \(String(format: "%.2f", confidence)))"
    }
}
