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

/// Configuration constants for the OCR engine and model files.
///
/// This module centralizes all configuration values to avoid magic numbers
/// and provide a single source of truth for OCR-related settings.
public enum OCRConfiguration {

    // MARK: - Model File Names

    /// Configuration for OCR model files bundled with the app.
    /// Models are pre-converted ONNX files from https://huggingface.co/monkt/paddleocr-onnx
    public enum ModelFiles {
        /// The filename for the text detection ONNX model (PP-OCRv3).
        public static let detectionModel = "det_v3.onnx"

        /// The filename for the text recognition ONNX model (English).
        public static let recognitionModel = "rec_english.onnx"

        /// The filename for the character dictionary used by the recognition model.
        public static let characterDictionary = "en_dict.txt"

        /// The directory name containing OCR model resources.
        public static let resourceDirectory = "OCRModels"
    }

    // MARK: - Model URLs

    /// URLs for downloading pre-converted PaddleOCR ONNX models from Hugging Face.
    /// Source: https://huggingface.co/monkt/paddleocr-onnx (Apache 2.0 License)
    public enum ModelURLs {
        /// Base URL for Hugging Face model repository.
        public static let baseURL = "https://huggingface.co/monkt/paddleocr-onnx/resolve/main"

        /// URL for the PP-OCRv3 text detection ONNX model.
        public static let detectionModel =
            "https://huggingface.co/monkt/paddleocr-onnx/resolve/main/detection/v3/det.onnx"

        /// URL for the English text recognition ONNX model.
        public static let recognitionModel =
            "https://huggingface.co/monkt/paddleocr-onnx/resolve/main/languages/english/rec.onnx"

        /// URL for the English character dictionary.
        public static let characterDictionary =
            "https://huggingface.co/monkt/paddleocr-onnx/resolve/main/languages/english/dict.txt"
    }

    // MARK: - Image Processing Settings

    /// Settings for image preprocessing before OCR.
    public enum ImageProcessing {
        /// Maximum dimension (width or height) for input images.
        /// Larger images will be resized while maintaining aspect ratio.
        public static let maxInputDimension = 960

        /// Minimum dimension (width or height) for input images.
        /// Smaller images may produce poor OCR results.
        public static let minInputDimension = 32

        /// The mean values for image normalization (RGB order).
        /// PaddleOCR uses [0.485, 0.456, 0.406] scaled to 0-255.
        public static let normalizationMean: [Float] = [123.675, 116.28, 103.53]

        /// The standard deviation values for image normalization (RGB order).
        /// PaddleOCR uses [0.229, 0.224, 0.225] scaled to 0-255.
        public static let normalizationStd: [Float] = [58.395, 57.12, 57.375]
    }

    // MARK: - Detection Settings

    /// Settings for the text detection model.
    public enum Detection {
        /// Threshold for binarizing the detection probability map.
        public static let binaryThreshold: Float = 0.3

        /// Threshold for filtering detected boxes by score.
        public static let boxThreshold: Float = 0.6

        /// Maximum number of candidate boxes to consider.
        public static let maxCandidates = 1000

        /// Factor for expanding detected text boxes.
        public static let unclipRatio: Float = 1.5

        /// Minimum size (area) for a valid text box.
        public static let minBoxSize = 3
    }

    // MARK: - Recognition Settings

    /// Settings for the text recognition model.
    public enum Recognition {
        /// Fixed height for recognition input images.
        public static let inputHeight = 48

        /// Maximum width for recognition input images.
        public static let maxInputWidth = 320

        /// Minimum confidence score to accept a recognized character.
        public static let confidenceThreshold: Float = 0.5
    }

    // MARK: - Network Settings

    /// Settings for network operations during model download.
    public enum Network {
        /// Maximum number of retry attempts for failed downloads.
        public static let maxRetryAttempts = 3

        /// Base delay in seconds for exponential backoff between retries.
        public static let retryBaseDelay: TimeInterval = 1.0

        /// Maximum delay in seconds between retry attempts.
        public static let retryMaxDelay: TimeInterval = 30.0

        /// Multiplier for exponential backoff calculation.
        public static let retryBackoffMultiplier: Double = 2.0

        /// Timeout in seconds for network requests.
        public static let requestTimeout: TimeInterval = 60.0

        /// Timeout in seconds for resource downloads (larger files).
        public static let downloadTimeout: TimeInterval = 300.0
    }

    // MARK: - Expected File Sizes

    /// Expected file sizes in bytes for validation (approximate).
    public enum ExpectedFileSizes {
        /// Approximate size of the detection ONNX model in bytes (~2.43 MB).
        public static let detectionModel = 2_500_000

        /// Approximate size of the recognition ONNX model in bytes (~7.83 MB).
        public static let recognitionModel = 8_000_000

        /// Approximate size of the character dictionary in bytes (~1.42 KB).
        public static let characterDictionary = 1_500

        /// Tolerance percentage for file size validation (0.0-1.0).
        /// Allows for minor variations in model files.
        public static let tolerancePercentage: Double = 0.2
    }
}
