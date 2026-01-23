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

/// Errors that can occur during OCR processing.
public enum OCRError: Error, Sendable {
    /// Failed to load an OCR model file.
    ///
    /// - Parameter message: Description of which model failed and why.
    case modelLoadFailed(String)

    /// Image preprocessing failed before inference.
    ///
    /// This typically occurs when:
    /// - The image format is unsupported
    /// - Memory allocation fails
    /// - The image dimensions are invalid
    case imagePreprocessingFailed

    /// An error occurred during model inference.
    ///
    /// - Parameter message: Description of the inference error.
    case inferenceError(String)

    /// Post-processing of model output failed.
    ///
    /// This can happen when:
    /// - Output tensor shape is unexpected
    /// - CTC decoding fails
    /// - Memory allocation fails during result construction
    case postProcessingFailed

    /// The input provided to the OCR engine is invalid.
    ///
    /// Common causes:
    /// - Nil or empty image
    /// - Image too small for OCR
    /// - Unsupported color space
    case invalidInput

    /// The OCR engine has not been initialized.
    ///
    /// Call `initialize()` on the OCREngine before attempting recognition.
    case notInitialized

    /// Character dictionary could not be loaded.
    ///
    /// The dictionary file is required for converting model output
    /// to readable text.
    case dictionaryLoadFailed
}

extension OCRError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .modelLoadFailed(let message):
            return "Model load failed: \(message)"
        case .imagePreprocessingFailed:
            return "Image preprocessing failed"
        case .inferenceError(let message):
            return "Inference error: \(message)"
        case .postProcessingFailed:
            return "Post-processing failed"
        case .invalidInput:
            return "Invalid input"
        case .notInitialized:
            return "OCR engine not initialized. Call initialize() first."
        case .dictionaryLoadFailed:
            return "Character dictionary load failed"
        }
    }
}

extension OCRError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
