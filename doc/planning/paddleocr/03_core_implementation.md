# Phase 3: Core Implementation

The main OCR engine using PaddleOCR models via ONNX Runtime.

## OCREngine.swift - Main OCR Interface

```swift
import Foundation
import CoreGraphics
import onnxruntime_objc

// MARK: - Constants

/// Constants for OCR processing parameters
private enum OCRConstants {
    /// Multiple for padding detection input (PaddleOCR requirement)
    static let detectionPaddingMultiple: Int = 32

    /// Target height for recognition model input
    static let recognitionTargetHeight: Int = 48

    /// Minimum width for recognition model input
    static let recognitionMinWidth: Int = 48

    /// Maximum width for recognition model input
    static let recognitionMaxWidth: Int = 320

    /// Minimum box dimension to filter noise
    static let minimumBoxDimension: Int = 5

    /// Threshold for considering text on the same line (in pixels)
    static let sameLineThreshold: CGFloat = 20

    /// Padding expansion for cropped text regions (in pixels)
    static let textRegionPadding: CGFloat = 2

    /// Number of threads for inference
    static let inferenceThreadCount: Int32 = 4

    /// ImageNet normalization mean values (RGB)
    static let normalizationMean: [Float] = [0.485, 0.456, 0.406]

    /// ImageNet normalization standard deviation values (RGB)
    static let normalizationStd: [Float] = [0.229, 0.224, 0.225]

    /// Recognition normalization offset
    static let recognitionNormOffset: Float = 0.5

    /// Detection model input tensor name
    static let detectionInputName = "x"

    /// Detection model output tensor name (varies by model version)
    static let detectionOutputName = "sigmoid_0.tmp_0"

    /// Recognition model input tensor name
    static let recognitionInputName = "x"

    /// Recognition model output tensor name (varies by model version)
    static let recognitionOutputName = "softmax_0.tmp_0"
}

/// Errors that can occur during OCR processing
public enum OCRError: Error, CustomStringConvertible {
    case modelLoadFailed(String)
    case imagePreprocessingFailed
    case inferenceError(String)
    case postProcessingFailed
    case invalidInput

    public var description: String {
        switch self {
        case .modelLoadFailed(let message): return "Model load failed: \(message)"
        case .imagePreprocessingFailed: return "Image preprocessing failed"
        case .inferenceError(let message): return "Inference error: \(message)"
        case .postProcessingFailed: return "Post-processing failed"
        case .invalidInput: return "Invalid input"
        }
    }
}

/// Configuration for OCR processing
public struct OCRConfiguration {
    /// Maximum image dimension (larger images will be scaled down)
    public var maxImageSize: CGFloat = 960

    /// Detection confidence threshold (0-1)
    public var detectionThreshold: Float = 0.3

    /// Recognition confidence threshold (0-1)
    public var recognitionThreshold: Float = 0.5

    /// Use CoreML execution provider if available
    public var useCoreML: Bool = true

    public init() {}
}

/// Main OCR engine using PaddleOCR models via ONNX Runtime
public final class OCREngine {

    // MARK: - Properties

    private let configuration: OCRConfiguration
    private var detectionSession: ORTSession?
    private var recognitionSession: ORTSession?
    private var characterDictionary: [String] = []
    private let sessionQueue = DispatchQueue(label: "com.locumtracker.ocr", qos: .userInitiated)

    private var isInitialized = false

    // MARK: - Initialization

    public init(configuration: OCRConfiguration = OCRConfiguration()) {
        self.configuration = configuration
    }

    /// Initialize the OCR engine by loading models
    /// Call this once at app startup or before first use
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

        // Configure session options
        let sessionOptions = try ORTSessionOptions()
        try sessionOptions.setGraphOptimizationLevel(.all)
        try sessionOptions.setIntraOpNumThreads(OCRConstants.inferenceThreadCount)

        // Enable CoreML if configured and available
        #if !targetEnvironment(simulator)
        if configuration.useCoreML {
            try sessionOptions.appendCoreMLExecutionProvider(with: .init())
        }
        #endif

        // Load detection model
        guard let detModelPath = Bundle.main.path(forResource: "pp_ocrv4_det", ofType: "onnx") else {
            throw OCRError.modelLoadFailed("Detection model not found in bundle")
        }
        detectionSession = try ORTSession(env: env, modelPath: detModelPath, sessionOptions: sessionOptions)

        // Load recognition model
        guard let recModelPath = Bundle.main.path(forResource: "pp_ocrv4_rec", ofType: "onnx") else {
            throw OCRError.modelLoadFailed("Recognition model not found in bundle")
        }
        recognitionSession = try ORTSession(env: env, modelPath: recModelPath, sessionOptions: sessionOptions)
    }

    private func loadDictionary() throws {
        guard let dictPath = Bundle.main.path(forResource: "ppocr_keys", ofType: "txt") else {
            throw OCRError.modelLoadFailed("Character dictionary not found in bundle")
        }

        let content = try String(contentsOfFile: dictPath, encoding: .utf8)
        characterDictionary = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Add blank token at the beginning (CTC blank)
        characterDictionary.insert(" ", at: 0)
    }

    // MARK: - Public API

    /// Recognize text in an image
    /// - Parameter image: CGImage to process
    /// - Returns: Array of recognized text lines with bounding boxes and confidence
    public func recognizeText(in image: CGImage) async throws -> [OCRResult] {
        guard isInitialized else {
            throw OCRError.modelLoadFailed("Engine not initialized. Call initialize() first.")
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
        let (detInput, scale, paddings) = try preprocessForDetection(image)

        // Step 2: Run text detection
        let textBoxes = try runDetection(input: detInput, originalSize: CGSize(width: image.width, height: image.height), scale: scale, paddings: paddings)

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

    private func preprocessForDetection(_ image: CGImage) throws -> (Data, CGFloat, (top: Int, bottom: Int, left: Int, right: Int)) {
        // Resize to max dimension while maintaining aspect ratio
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

        // Round to multiple of padding requirement (required by detection model)
        let paddingMultiple = CGFloat(OCRConstants.detectionPaddingMultiple)
        let targetWidth = Int(ceil(newWidth / paddingMultiple) * paddingMultiple)
        let targetHeight = Int(ceil(newHeight / paddingMultiple) * paddingMultiple)

        // Calculate padding
        let padRight = targetWidth - Int(newWidth)
        let padBottom = targetHeight - Int(newHeight)

        // Create resized and padded image
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw OCRError.imagePreprocessingFailed
        }

        // Fill with white (padding color)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Draw image
        context.draw(image, in: CGRect(x: 0, y: CGFloat(padBottom), width: newWidth, height: newHeight))

        guard let resizedImage = context.makeImage(),
              let pixelData = resizedImage.dataProvider?.data else {
            throw OCRError.imagePreprocessingFailed
        }

        let data = pixelData as Data

        // Convert to normalized float tensor [1, 3, H, W] in RGB order
        // PaddleOCR uses ImageNet normalization: mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
        var floatData = [Float](repeating: 0, count: 3 * targetWidth * targetHeight)

        let mean = OCRConstants.normalizationMean
        let std = OCRConstants.normalizationStd
        let bytesPerPixel = 4

        for y in 0..<targetHeight {
            for x in 0..<targetWidth {
                let pixelIndex = (y * targetWidth + x) * bytesPerPixel
                let r = Float(data[pixelIndex]) / 255.0
                let g = Float(data[pixelIndex + 1]) / 255.0
                let b = Float(data[pixelIndex + 2]) / 255.0

                // Normalize and store in CHW format (Channels, Height, Width)
                let hw = targetWidth * targetHeight
                floatData[0 * hw + y * targetWidth + x] = (r - mean[0]) / std[0]  // R channel
                floatData[1 * hw + y * targetWidth + x] = (g - mean[1]) / std[1]  // G channel
                floatData[2 * hw + y * targetWidth + x] = (b - mean[2]) / std[2]  // B channel
            }
        }

        let tensorData = Data(bytes: floatData, count: floatData.count * MemoryLayout<Float>.size)

        return (tensorData, scale, (top: 0, bottom: padBottom, left: 0, right: padRight))
    }

    private func runDetection(input: Data, originalSize: CGSize, scale: CGFloat, paddings: (top: Int, bottom: Int, left: Int, right: Int)) throws -> [CGRect] {
        guard let session = detectionSession else {
            throw OCRError.inferenceError("Detection session not initialized")
        }

        // Get input shape from preprocessing
        let paddingMultiple = CGFloat(OCRConstants.detectionPaddingMultiple)
        let height = Int(ceil(originalSize.height * scale / paddingMultiple) * paddingMultiple)
        let width = Int(ceil(originalSize.width * scale / paddingMultiple) * paddingMultiple)

        let inputShape: [NSNumber] = [1, 3, NSNumber(value: height), NSNumber(value: width)]

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

        // Post-process detection output to get bounding boxes
        let boxes = postProcessDetection(
            outputData: outputData,
            width: width,
            height: height,
            originalSize: originalSize,
            scale: scale,
            threshold: configuration.detectionThreshold
        )

        return boxes
    }

    private func postProcessDetection(outputData: Data, width: Int, height: Int, originalSize: CGSize, scale: CGFloat, threshold: Float) -> [CGRect] {
        // Convert output data to float array
        let floatCount = outputData.count / MemoryLayout<Float>.size
        var floatArray = [Float](repeating: 0, count: floatCount)
        _ = floatArray.withUnsafeMutableBytes { outputData.copyBytes(to: $0) }

        // Binary threshold the probability map
        var binaryMap = [UInt8](repeating: 0, count: width * height)
        for i in 0..<min(floatArray.count, width * height) {
            binaryMap[i] = floatArray[i] > threshold ? 255 : 0
        }

        // Find contours (simplified - in production use OpenCV or Accelerate)
        var boxes: [CGRect] = []
        var visited = [Bool](repeating: false, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if binaryMap[idx] > 0 && !visited[idx] {
                    // Flood fill to find connected component
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

                    // Filter small boxes (likely noise)
                    let boxWidth = maxX - minX
                    let boxHeight = maxY - minY
                    if boxWidth > OCRConstants.minimumBoxDimension && boxHeight > OCRConstants.minimumBoxDimension {
                        // Convert back to original image coordinates
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
        // Expand box slightly for better recognition
        let expandedBox = box.insetBy(dx: -OCRConstants.textRegionPadding, dy: -OCRConstants.textRegionPadding)
        let clampedBox = CGRect(
            x: max(0, expandedBox.origin.x),
            y: max(0, expandedBox.origin.y),
            width: min(expandedBox.width, CGFloat(image.width) - expandedBox.origin.x),
            height: min(expandedBox.height, CGFloat(image.height) - expandedBox.origin.y)
        )

        return image.cropping(to: clampedBox)
    }

    /// Preprocesses an image for recognition and returns the tensor data with dimensions
    /// - Parameter image: The cropped text region image
    /// - Returns: Tuple of (tensor data, target width) for building the input tensor
    private func preprocessForRecognition(_ image: CGImage) throws -> (Data, Int) {
        // Target height is fixed, width is variable based on aspect ratio
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
            bytesPerRow: targetWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw OCRError.imagePreprocessingFailed
        }

        // Fill with white
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Draw image maintaining aspect ratio
        let drawWidth = min(targetWidth, Int(CGFloat(targetHeight) * aspectRatio))
        context.draw(image, in: CGRect(x: 0, y: 0, width: drawWidth, height: targetHeight))

        guard let resizedImage = context.makeImage(),
              let pixelData = resizedImage.dataProvider?.data else {
            throw OCRError.imagePreprocessingFailed
        }

        let data = pixelData as Data

        // Convert to normalized float tensor
        var floatData = [Float](repeating: 0, count: 3 * targetWidth * targetHeight)
        let normOffset = OCRConstants.recognitionNormOffset
        let bytesPerPixel = 4

        for y in 0..<targetHeight {
            for x in 0..<targetWidth {
                let pixelIndex = (y * targetWidth + x) * bytesPerPixel
                let r = Float(data[pixelIndex]) / 255.0
                let g = Float(data[pixelIndex + 1]) / 255.0
                let b = Float(data[pixelIndex + 2]) / 255.0

                // Normalize to [-1, 1] range (PaddleOCR recognition preprocessing)
                let hw = targetWidth * targetHeight
                floatData[0 * hw + y * targetWidth + x] = (r - normOffset) / normOffset
                floatData[1 * hw + y * targetWidth + x] = (g - normOffset) / normOffset
                floatData[2 * hw + y * targetWidth + x] = (b - normOffset) / normOffset
            }
        }

        let tensorData = Data(bytes: floatData, count: floatData.count * MemoryLayout<Float>.size)
        return (tensorData, targetWidth)
    }

    /// Runs recognition inference on preprocessed image data
    /// - Parameters:
    ///   - input: Preprocessed tensor data
    ///   - width: Width of the preprocessed image
    /// - Returns: Tuple of (recognized text, confidence score)
    private func runRecognition(input: Data, width: Int) throws -> (String, Float) {
        guard let session = recognitionSession else {
            throw OCRError.inferenceError("Recognition session not initialized")
        }

        // Input shape for recognition: [1, 3, height, width]
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

        // Decode CTC output
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
            // Find max probability class
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

// MARK: - OCR Result

/// Result of text recognition for a single text region
public struct OCRResult: Identifiable {
    public let id = UUID()

    /// Recognized text
    public let text: String

    /// Bounding box in original image coordinates
    public let boundingBox: CGRect

    /// Recognition confidence (0-1)
    public let confidence: Float
}
```

---

**Previous:** [02_project_setup.md](02_project_setup.md)
**Next:** [04_camera_integration.md](04_camera_integration.md) - Camera capture view for iOS
