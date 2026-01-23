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
import OnnxRuntimeBindings

// MARK: - Constants

/// Internal constants for OCR processing parameters.
private enum OCRConstants {
    /// Multiple for padding detection input (PaddleOCR requirement).
    static let detectionPaddingMultiple: Int = 32

    /// Target height for recognition model input.
    static let recognitionTargetHeight: Int = 48

    /// Minimum width for recognition model input.
    static let recognitionMinWidth: Int = 48

    /// Maximum width for recognition model input.
    static let recognitionMaxWidth: Int = 320

    /// Minimum box dimension to filter noise.
    static let minimumBoxDimension: Int = 5

    /// Threshold for considering text on the same line (in pixels).
    static let sameLineThreshold: CGFloat = 20

    /// Padding expansion for cropped text regions (in pixels).
    static let textRegionPadding: CGFloat = 2

    /// Number of threads for inference.
    static let inferenceThreadCount: Int32 = 4

    /// ImageNet normalization mean values (RGB).
    static let normalizationMean: [Float] = [0.485, 0.456, 0.406]

    /// ImageNet normalization standard deviation values (RGB).
    static let normalizationStd: [Float] = [0.229, 0.224, 0.225]

    /// Recognition normalization offset.
    static let recognitionNormOffset: Float = 0.5

    /// Detection model input tensor name.
    static let detectionInputName = "x"

    /// Detection model output tensor name (PP-OCRv3).
    static let detectionOutputName = "sigmoid_0.tmp_0"

    /// Recognition model input tensor name.
    static let recognitionInputName = "x"

    /// Recognition model output tensor name.
    static let recognitionOutputName = "softmax_0.tmp_0"

    /// Bytes per pixel in RGBA format.
    static let bytesPerPixel = 4

    /// Number of color channels (RGB).
    static let colorChannels = 3
}

/// Runtime configuration for OCR processing.
public struct OCREngineConfiguration: Sendable {
    /// Maximum image dimension (larger images will be scaled down).
    public var maxImageSize: CGFloat

    /// Detection confidence threshold (0-1).
    public var detectionThreshold: Float

    /// Recognition confidence threshold (0-1).
    public var recognitionThreshold: Float

    /// Use CoreML execution provider if available.
    public var useCoreML: Bool

    /// Creates a new OCR engine configuration with default values.
    public init(
        maxImageSize: CGFloat = 960,
        detectionThreshold: Float = 0.3,
        recognitionThreshold: Float = 0.5,
        useCoreML: Bool = true
    ) {
        self.maxImageSize = maxImageSize
        self.detectionThreshold = detectionThreshold
        self.recognitionThreshold = recognitionThreshold
        self.useCoreML = useCoreML
    }
}

/// Main OCR engine using PaddleOCR models via ONNX Runtime.
///
/// This engine provides text detection and recognition for images,
/// optimized for receipt scanning on iOS and macOS.
///
/// ## Usage
/// ```swift
/// let engine = OCREngine()
/// try await engine.initialize()
/// let results = try await engine.recognizeText(in: cgImage)
/// for result in results {
///     print("\(result.text) (confidence: \(result.confidence))")
/// }
/// ```
///
/// ## Thread Safety
/// The OCREngine is designed for concurrent use. The `recognizeText` method
/// can be called from multiple tasks concurrently.
public final class OCREngine: @unchecked Sendable {

    // MARK: - Properties

    private let configuration: OCREngineConfiguration
    private var ortEnv: ORTEnv?
    private var detectionSession: ORTSession?
    private var recognitionSession: ORTSession?
    private var characterDictionary: [String] = []
    private let sessionQueue = DispatchQueue(label: "com.locumtracker.ocr", qos: .userInitiated)

    private var isInitialized = false

    // MARK: - Initialization

    /// Creates a new OCR engine with the specified configuration.
    ///
    /// - Parameter configuration: Configuration for OCR processing.
    public init(configuration: OCREngineConfiguration = OCREngineConfiguration()) {
        self.configuration = configuration
    }

    /// Initializes the OCR engine by loading models.
    ///
    /// Call this once at app startup or before first use.
    /// This method loads the detection and recognition models and
    /// prepares the engine for inference.
    ///
    /// - Throws: `OCRError.modelLoadFailed` if models cannot be loaded.
    public func initialize() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: OCRError.modelLoadFailed("Engine deallocated"))
                    return
                }

                do {
                    try self.loadModels()
                    try self.loadDictionary()
                    self.isInitialized = true
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Model Loading

    private func loadModels() throws {
        let env = try ORTEnv(loggingLevel: .warning)
        self.ortEnv = env

        let sessionOptions = try ORTSessionOptions()
        try sessionOptions.setGraphOptimizationLevel(.all)
        try sessionOptions.setIntraOpNumThreads(OCRConstants.inferenceThreadCount)

        #if !targetEnvironment(simulator)
        if configuration.useCoreML {
            try sessionOptions.appendCoreMLExecutionProvider(with: ORTCoreMLExecutionProviderOptions())
        }
        #endif

        // Load detection model from bundle resources
        guard let detModelPath = findModelPath(
            filename: OCRConfiguration.ModelFiles.detectionModel
        ) else {
            throw OCRError.modelLoadFailed(
                "Detection model '\(OCRConfiguration.ModelFiles.detectionModel)' not found in bundle"
            )
        }
        detectionSession = try ORTSession(env: env, modelPath: detModelPath, sessionOptions: sessionOptions)

        // Load recognition model from bundle resources
        guard let recModelPath = findModelPath(
            filename: OCRConfiguration.ModelFiles.recognitionModel
        ) else {
            throw OCRError.modelLoadFailed(
                "Recognition model '\(OCRConfiguration.ModelFiles.recognitionModel)' not found in bundle"
            )
        }
        recognitionSession = try ORTSession(env: env, modelPath: recModelPath, sessionOptions: sessionOptions)
    }

    private func findModelPath(filename: String) -> String? {
        // Try to find in the package bundle first
        let bundle = Bundle.module

        // Try direct resource lookup
        let nameWithoutExtension = (filename as NSString).deletingPathExtension
        let extensionPart = (filename as NSString).pathExtension

        if let path = bundle.path(forResource: nameWithoutExtension, ofType: extensionPart) {
            return path
        }

        // Try looking in OCRModels subdirectory
        if let path = bundle.path(
            forResource: nameWithoutExtension,
            ofType: extensionPart,
            inDirectory: OCRConfiguration.ModelFiles.resourceDirectory
        ) {
            return path
        }

        // Fallback to main bundle
        if let path = Bundle.main.path(forResource: nameWithoutExtension, ofType: extensionPart) {
            return path
        }

        return nil
    }

    private func loadDictionary() throws {
        guard let dictPath = findModelPath(
            filename: OCRConfiguration.ModelFiles.characterDictionary
        ) else {
            throw OCRError.dictionaryLoadFailed
        }

        let content = try String(contentsOfFile: dictPath, encoding: .utf8)
        characterDictionary = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Add blank token at the beginning (CTC blank)
        characterDictionary.insert(" ", at: 0)
    }

    // MARK: - Public API

    /// Recognizes text in an image.
    ///
    /// - Parameter image: CGImage to process.
    /// - Returns: Array of recognized text lines with bounding boxes and confidence.
    /// - Throws: `OCRError` if recognition fails.
    public func recognizeText(in image: CGImage) async throws -> [OCRResult] {
        guard isInitialized else {
            throw OCRError.notInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: OCRError.inferenceError("Engine deallocated"))
                    return
                }

                do {
                    let results = try self.processImage(image)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Processing Pipeline

    private func processImage(_ image: CGImage) throws -> [OCRResult] {
        // Step 1: Preprocess image for detection
        let (detInput, scale, paddings, targetWidth, targetHeight) = try preprocessForDetection(image)

        // Step 2: Run text detection
        let textBoxes = try runDetection(
            input: detInput,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            originalSize: CGSize(width: image.width, height: image.height),
            scale: scale,
            paddings: paddings
        )

        // Step 3: For each detected box, crop and run recognition
        var results: [OCRResult] = []

        for box in textBoxes {
            guard let croppedImage = cropTextRegion(from: image, box: box) else {
                continue
            }

            let (recInput, recWidth) = try preprocessForRecognition(croppedImage)
            let (text, confidence) = try runRecognition(input: recInput, width: recWidth)

            if confidence >= configuration.recognitionThreshold && !text.isEmpty {
                results.append(OCRResult(
                    text: text,
                    boundingBox: box,
                    confidence: confidence
                ))
            }
        }

        // Sort results top-to-bottom, left-to-right
        results.sort { a, b in
            let yDiff = abs(a.boundingBox.origin.y - b.boundingBox.origin.y)
            if yDiff < OCRConstants.sameLineThreshold {
                return a.boundingBox.origin.x < b.boundingBox.origin.x
            }
            return a.boundingBox.origin.y < b.boundingBox.origin.y
        }

        return results
    }

    // MARK: - Detection

    private func preprocessForDetection(_ image: CGImage) throws -> (Data, CGFloat, (top: Int, bottom: Int, left: Int, right: Int), Int, Int) {
        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)

        var scale: CGFloat = 1.0
        var newWidth = originalWidth
        var newHeight = originalHeight

        let maxDim = max(originalWidth, originalHeight)
        if maxDim > configuration.maxImageSize {
            scale = configuration.maxImageSize / maxDim
            newWidth = originalWidth * scale
            newHeight = originalHeight * scale
        }

        // Round to multiple of padding requirement
        let paddingMultiple = CGFloat(OCRConstants.detectionPaddingMultiple)
        let targetWidth = Int(ceil(newWidth / paddingMultiple) * paddingMultiple)
        let targetHeight = Int(ceil(newHeight / paddingMultiple) * paddingMultiple)

        let padRight = targetWidth - Int(newWidth)
        let padBottom = targetHeight - Int(newHeight)

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * OCRConstants.bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw OCRError.imagePreprocessingFailed
        }

        // Fill with white (padding color)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Draw image (flip Y because CGContext has origin at bottom-left)
        context.draw(image, in: CGRect(x: 0, y: CGFloat(padBottom), width: newWidth, height: newHeight))

        guard let resizedImage = context.makeImage(),
              let pixelData = resizedImage.dataProvider?.data else {
            throw OCRError.imagePreprocessingFailed
        }

        let data = pixelData as Data

        // Convert to normalized float tensor [1, 3, H, W] in RGB order
        var floatData = [Float](repeating: 0, count: OCRConstants.colorChannels * targetWidth * targetHeight)

        let mean = OCRConstants.normalizationMean
        let std = OCRConstants.normalizationStd

        for y in 0..<targetHeight {
            for x in 0..<targetWidth {
                let pixelIndex = (y * targetWidth + x) * OCRConstants.bytesPerPixel
                let r = Float(data[pixelIndex]) / 255.0
                let g = Float(data[pixelIndex + 1]) / 255.0
                let b = Float(data[pixelIndex + 2]) / 255.0

                // Store in CHW format (Channels, Height, Width)
                let hw = targetWidth * targetHeight
                floatData[0 * hw + y * targetWidth + x] = (r - mean[0]) / std[0]
                floatData[1 * hw + y * targetWidth + x] = (g - mean[1]) / std[1]
                floatData[2 * hw + y * targetWidth + x] = (b - mean[2]) / std[2]
            }
        }

        let tensorData = Data(bytes: floatData, count: floatData.count * MemoryLayout<Float>.size)

        return (tensorData, scale, (top: 0, bottom: padBottom, left: 0, right: padRight), targetWidth, targetHeight)
    }

    private func runDetection(
        input: Data,
        targetWidth: Int,
        targetHeight: Int,
        originalSize: CGSize,
        scale: CGFloat,
        paddings: (top: Int, bottom: Int, left: Int, right: Int)
    ) throws -> [CGRect] {
        guard let session = detectionSession else {
            throw OCRError.inferenceError("Detection session not initialized")
        }

        let inputShape: [NSNumber] = [1, 3, NSNumber(value: targetHeight), NSNumber(value: targetWidth)]

        let inputTensor = try ORTValue(
            tensorData: NSMutableData(data: input),
            elementType: .float,
            shape: inputShape
        )

        let outputs = try session.run(
            withInputs: [OCRConstants.detectionInputName: inputTensor],
            outputNames: [OCRConstants.detectionOutputName],
            runOptions: nil
        )

        guard let outputTensor = outputs[OCRConstants.detectionOutputName],
              let outputData = try? outputTensor.tensorData() as Data else {
            throw OCRError.inferenceError("Failed to get detection output")
        }

        let boxes = postProcessDetection(
            outputData: outputData,
            width: targetWidth,
            height: targetHeight,
            originalSize: originalSize,
            scale: scale,
            threshold: configuration.detectionThreshold
        )

        return boxes
    }

    private func postProcessDetection(
        outputData: Data,
        width: Int,
        height: Int,
        originalSize: CGSize,
        scale: CGFloat,
        threshold: Float
    ) -> [CGRect] {
        let floatCount = outputData.count / MemoryLayout<Float>.size
        var floatArray = [Float](repeating: 0, count: floatCount)
        _ = floatArray.withUnsafeMutableBytes { outputData.copyBytes(to: $0) }

        // Binary threshold the probability map
        var binaryMap = [UInt8](repeating: 0, count: width * height)
        for i in 0..<min(floatArray.count, width * height) {
            binaryMap[i] = floatArray[i] > threshold ? 255 : 0
        }

        // Find connected components (simplified flood fill)
        var boxes: [CGRect] = []
        var visited = [Bool](repeating: false, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if binaryMap[idx] > 0 && !visited[idx] {
                    var minX = x, maxX = x, minY = y, maxY = y
                    var stack = [(x, y)]

                    while !stack.isEmpty {
                        let (cx, cy) = stack.removeLast()
                        let cidx = cy * width + cx

                        if cx < 0 || cx >= width || cy < 0 || cy >= height { continue }
                        if visited[cidx] || binaryMap[cidx] == 0 { continue }

                        visited[cidx] = true
                        minX = min(minX, cx)
                        maxX = max(maxX, cx)
                        minY = min(minY, cy)
                        maxY = max(maxY, cy)

                        stack.append((cx + 1, cy))
                        stack.append((cx - 1, cy))
                        stack.append((cx, cy + 1))
                        stack.append((cx, cy - 1))
                    }

                    let boxWidth = maxX - minX
                    let boxHeight = maxY - minY
                    if boxWidth > OCRConstants.minimumBoxDimension && boxHeight > OCRConstants.minimumBoxDimension {
                        let rect = CGRect(
                            x: CGFloat(minX) / scale,
                            y: CGFloat(minY) / scale,
                            width: CGFloat(boxWidth) / scale,
                            height: CGFloat(boxHeight) / scale
                        )
                        boxes.append(rect)
                    }
                }
            }
        }

        return boxes
    }

    // MARK: - Recognition

    private func cropTextRegion(from image: CGImage, box: CGRect) -> CGImage? {
        let expandedBox = box.insetBy(dx: -OCRConstants.textRegionPadding, dy: -OCRConstants.textRegionPadding)
        let clampedBox = CGRect(
            x: max(0, expandedBox.origin.x),
            y: max(0, expandedBox.origin.y),
            width: min(expandedBox.width, CGFloat(image.width) - max(0, expandedBox.origin.x)),
            height: min(expandedBox.height, CGFloat(image.height) - max(0, expandedBox.origin.y))
        )

        guard clampedBox.width > 0 && clampedBox.height > 0 else {
            return nil
        }

        return image.cropping(to: clampedBox)
    }

    private func preprocessForRecognition(_ image: CGImage) throws -> (Data, Int) {
        let targetHeight = OCRConstants.recognitionTargetHeight
        let aspectRatio = CGFloat(image.width) / CGFloat(image.height)
        let targetWidth = max(
            OCRConstants.recognitionMinWidth,
            min(OCRConstants.recognitionMaxWidth, Int(CGFloat(targetHeight) * aspectRatio))
        )

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * OCRConstants.bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw OCRError.imagePreprocessingFailed
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        let drawWidth = min(targetWidth, Int(CGFloat(targetHeight) * aspectRatio))
        context.draw(image, in: CGRect(x: 0, y: 0, width: drawWidth, height: targetHeight))

        guard let resizedImage = context.makeImage(),
              let pixelData = resizedImage.dataProvider?.data else {
            throw OCRError.imagePreprocessingFailed
        }

        let data = pixelData as Data

        var floatData = [Float](repeating: 0, count: OCRConstants.colorChannels * targetWidth * targetHeight)
        let normOffset = OCRConstants.recognitionNormOffset

        for y in 0..<targetHeight {
            for x in 0..<targetWidth {
                let pixelIndex = (y * targetWidth + x) * OCRConstants.bytesPerPixel
                let r = Float(data[pixelIndex]) / 255.0
                let g = Float(data[pixelIndex + 1]) / 255.0
                let b = Float(data[pixelIndex + 2]) / 255.0

                // Normalize to [-1, 1] range
                let hw = targetWidth * targetHeight
                floatData[0 * hw + y * targetWidth + x] = (r - normOffset) / normOffset
                floatData[1 * hw + y * targetWidth + x] = (g - normOffset) / normOffset
                floatData[2 * hw + y * targetWidth + x] = (b - normOffset) / normOffset
            }
        }

        let tensorData = Data(bytes: floatData, count: floatData.count * MemoryLayout<Float>.size)
        return (tensorData, targetWidth)
    }

    private func runRecognition(input: Data, width: Int) throws -> (String, Float) {
        guard let session = recognitionSession else {
            throw OCRError.inferenceError("Recognition session not initialized")
        }

        let targetHeight = OCRConstants.recognitionTargetHeight
        let inputShape: [NSNumber] = [1, 3, NSNumber(value: targetHeight), NSNumber(value: width)]

        let inputTensor = try ORTValue(
            tensorData: NSMutableData(data: input),
            elementType: .float,
            shape: inputShape
        )

        let outputs = try session.run(
            withInputs: [OCRConstants.recognitionInputName: inputTensor],
            outputNames: [OCRConstants.recognitionOutputName],
            runOptions: nil
        )

        guard let outputTensor = outputs[OCRConstants.recognitionOutputName],
              let outputData = try? outputTensor.tensorData() as Data,
              let shape = try? outputTensor.tensorTypeAndShapeInfo().shape else {
            throw OCRError.inferenceError("Failed to get recognition output")
        }

        return decodeCTCOutput(outputData: outputData, shape: shape.map { $0.intValue })
    }

    private func decodeCTCOutput(outputData: Data, shape: [Int]) -> (String, Float) {
        // Shape is [1, T, num_classes] where T is sequence length
        guard shape.count == 3 else {
            return ("", 0)
        }

        let seqLength = shape[1]
        let numClasses = shape[2]

        var floatArray = [Float](repeating: 0, count: outputData.count / MemoryLayout<Float>.size)
        _ = floatArray.withUnsafeMutableBytes { outputData.copyBytes(to: $0) }

        var result = ""
        var totalConfidence: Float = 0
        var charCount = 0
        var lastIndex = -1

        for t in 0..<seqLength {
            var maxProb: Float = 0
            var maxIndex = 0

            for c in 0..<numClasses {
                let prob = floatArray[t * numClasses + c]
                if prob > maxProb {
                    maxProb = prob
                    maxIndex = c
                }
            }

            // CTC decoding: skip blanks (index 0) and repeated characters
            if maxIndex != 0 && maxIndex != lastIndex {
                if maxIndex < characterDictionary.count {
                    result += characterDictionary[maxIndex]
                    totalConfidence += maxProb
                    charCount += 1
                }
            }
            lastIndex = maxIndex
        }

        let avgConfidence = charCount > 0 ? totalConfidence / Float(charCount) : 0
        return (result, avgConfidence)
    }
}
