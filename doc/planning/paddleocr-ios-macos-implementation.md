# PaddleOCR Implementation Guide: iOS and macOS

*Implementation planning document for LocumTracker*

This guide details how to integrate PaddleOCR for on-device receipt text extraction on iOS and macOS using ONNX Runtime.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Model Preparation](#model-preparation)
4. [Project Setup](#project-setup)
5. [Core Implementation](#core-implementation)
6. [Camera Integration](#camera-integration)
7. [Receipt Data Extraction](#receipt-data-extraction)
8. [Performance Optimization](#performance-optimization)
9. [Testing Strategy](#testing-strategy)
10. [Fallback Strategy](#fallback-strategy)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      LocumTracker App                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │   Camera    │───▶│  OCR Engine │───▶│  Receipt Parser     │  │
│  │   Capture   │    │  (PaddleOCR)│    │  (Regex/Foundation) │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
│         │                  │                      │              │
│         ▼                  ▼                      ▼              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │   CGImage   │    │ ONNX Runtime│    │   ReceiptData       │  │
│  │             │    │   + Models  │    │   (Structured)      │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

Models bundled in app (~10MB total):
- pp_ocrv4_det.onnx (Text Detection)
- pp_ocrv4_rec.onnx (Text Recognition)
- ppocr_keys.txt (Character dictionary)
```

### Why ONNX Runtime over Paddle-Lite on Apple Platforms?

1. **CoreML Integration**: ONNX Runtime supports CoreML as an execution provider, leveraging Apple Neural Engine
2. **Better Swift Support**: More mature Swift bindings and documentation
3. **Cross-platform Consistency**: Same runtime can be used on Android
4. **Active Maintenance**: Microsoft actively maintains mobile packages

---

## Prerequisites

### Development Environment

- Xcode 15.0+ (for iOS 17+ deployment)
- macOS 14.0+ (Sonoma) for development
- Swift 5.9+
- CocoaPods or Swift Package Manager

### Target Platforms

| Platform | Minimum Version | Recommended |
|----------|-----------------|-------------|
| iOS | 15.0 | 17.0+ |
| macOS | 12.0 | 14.0+ |

### Required Skills

- Swift/SwiftUI development
- Basic understanding of image processing
- Familiarity with async/await patterns

---

## Model Preparation

### Step 1: Download PaddleOCR Models

```bash
# Create models directory
mkdir -p Resources/OCRModels

# Download PP-OCRv4 mobile models from PaddleOCR releases
# Detection model
wget https://paddleocr.bj.bcebos.com/PP-OCRv4/chinese/ch_PP-OCRv4_det_infer.tar
tar -xf ch_PP-OCRv4_det_infer.tar

# Recognition model
wget https://paddleocr.bj.bcebos.com/PP-OCRv4/chinese/ch_PP-OCRv4_rec_infer.tar
tar -xf ch_PP-OCRv4_rec_infer.tar

# For English-only (smaller):
wget https://paddleocr.bj.bcebos.com/PP-OCRv4/english/en_PP-OCRv4_rec_infer.tar
```

### Step 2: Convert to ONNX Format

```bash
# Install paddle2onnx
pip install paddle2onnx paddlepaddle

# Convert detection model
paddle2onnx --model_dir ch_PP-OCRv4_det_infer \
    --model_filename inference.pdmodel \
    --params_filename inference.pdiparams \
    --save_file pp_ocrv4_det.onnx \
    --opset_version 12 \
    --input_shape_dict="{'x':[-1,3,-1,-1]}"

# Convert recognition model
paddle2onnx --model_dir ch_PP-OCRv4_rec_infer \
    --model_filename inference.pdmodel \
    --params_filename inference.pdiparams \
    --save_file pp_ocrv4_rec.onnx \
    --opset_version 12 \
    --input_shape_dict="{'x':[-1,3,-1,-1]}"
```

### Step 3: Download Character Dictionary

```bash
# Download the recognition dictionary
wget https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/main/ppocr/utils/ppocr_keys_v1.txt \
    -O ppocr_keys.txt

# For English-only:
wget https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/main/ppocr/utils/en_dict.txt \
    -O en_dict.txt
```

### Final Model Files

```
Resources/OCRModels/
├── pp_ocrv4_det.onnx      (~3.5 MB)
├── pp_ocrv4_rec.onnx      (~4.5 MB)
└── ppocr_keys.txt         (~200 KB)
```

---

## Project Setup

### Option A: Swift Package Manager (Recommended)

Add to `Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LocumTrackerOCR",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "LocumTrackerOCR", targets: ["LocumTrackerOCR"])
    ],
    dependencies: [
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager", from: "1.16.0")
    ],
    targets: [
        .target(
            name: "LocumTrackerOCR",
            dependencies: [
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager")
            ],
            resources: [
                .copy("Resources/OCRModels")
            ]
        )
    ]
)
```

### Option B: CocoaPods

```ruby
# Podfile
platform :ios, '15.0'

target 'LocumTracker' do
  use_frameworks!

  pod 'onnxruntime-objc', '~> 1.16.0'
  # Or for smaller size with CoreML support:
  pod 'onnxruntime-mobile-objc', '~> 1.16.0'
end
```

### Add Models to Xcode Project

1. Drag `Resources/OCRModels` folder into Xcode project navigator
2. Ensure "Copy items if needed" is checked
3. Add to target membership for both iOS and macOS targets
4. Verify models appear in "Copy Bundle Resources" build phase

---

## Core Implementation

### OCREngine.swift - Main OCR Interface

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

### OCRResultProcessor.swift - Receipt Data Extraction

```swift
import Foundation

/// Extracted receipt data
public struct ReceiptData {
    public var merchant: String?
    public var totalAmount: Decimal?
    public var subtotal: Decimal?
    public var gstAmount: Decimal?
    public var date: Date?
    public var rawText: String
    public var confidence: Float

    public init(rawText: String, confidence: Float) {
        self.rawText = rawText
        self.confidence = confidence
    }
}

/// Processes OCR results to extract structured receipt data
public final class ReceiptDataExtractor {

    // MARK: - Regex Patterns (Australian receipts)

    private static let totalPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:TOTAL|Total|AMOUNT DUE|Balance Due|TO PAY)[:\s]*\$?\s*([\d,]+\.\d{2})"#,
            #"(?:EFTPOS|CARD|VISA|MASTERCARD|PAID)[:\s]*\$?\s*([\d,]+\.\d{2})"#,
            #"\$\s*([\d,]+\.\d{2})\s*(?:TOTAL|AUD)?"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private static let gstPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:GST|G\.S\.T\.|TAX)[:\s]*\$?\s*([\d,]+\.\d{2})"#,
            #"(?:Includes GST of|GST Included)[:\s]*\$?\s*([\d,]+\.\d{2})"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private static let datePatterns: [NSRegularExpression] = {
        let patterns = [
            #"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})"#,  // DD/MM/YYYY or DD-MM-YY
            #"(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{2,4})"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private static let abnPattern: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"ABN[:\s]*(\d{2}\s*\d{3}\s*\d{3}\s*\d{3})"#, options: .caseInsensitive)
    }()

    // Common Australian merchants
    private static let knownMerchants = [
        "WOOLWORTHS", "COLES", "ALDI", "IGA", "COSTCO",
        "BUNNINGS", "OFFICEWORKS", "JB HI-FI", "KMART", "TARGET", "BIG W",
        "BP", "SHELL", "CALTEX", "7-ELEVEN", "AMPOL",
        "CHEMIST WAREHOUSE", "PRICELINE", "TERRY WHITE",
        "MCDONALD'S", "SUBWAY", "KFC", "HUNGRY JACK'S"
    ]

    // MARK: - Public API

    /// Extract structured data from OCR results
    public static func extract(from ocrResults: [OCRResult]) -> ReceiptData {
        let fullText = ocrResults.map { $0.text }.joined(separator: "\n")
        let avgConfidence = ocrResults.isEmpty ? 0 : ocrResults.reduce(0) { $0 + $1.confidence } / Float(ocrResults.count)

        var receiptData = ReceiptData(rawText: fullText, confidence: avgConfidence)

        // Extract merchant (usually first few lines)
        receiptData.merchant = extractMerchant(from: ocrResults)

        // Extract amounts
        receiptData.totalAmount = extractTotal(from: fullText)
        receiptData.gstAmount = extractGST(from: fullText)

        // Extract date
        receiptData.date = extractDate(from: fullText)

        return receiptData
    }

    // MARK: - Extraction Methods

    private static func extractMerchant(from results: [OCRResult]) -> String? {
        // Take first 5 lines as candidates
        let topLines = results.prefix(5).map { $0.text.uppercased().trimmingCharacters(in: .whitespaces) }

        // Check for known merchants
        for line in topLines {
            for merchant in knownMerchants {
                if line.contains(merchant) {
                    return merchant.capitalized
                }
            }
        }

        // Return first non-empty, non-numeric line
        for line in topLines {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty && !cleaned.allSatisfy({ $0.isNumber || $0 == " " }) {
                return cleaned.capitalized
            }
        }

        return nil
    }

    private static func extractTotal(from text: String) -> Decimal? {
        for pattern in totalPatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, options: [], range: range) {
                if let amountRange = Range(match.range(at: 1), in: text) {
                    let amountString = String(text[amountRange]).replacingOccurrences(of: ",", with: "")
                    return Decimal(string: amountString)
                }
            }
        }
        return nil
    }

    private static func extractGST(from text: String) -> Decimal? {
        for pattern in gstPatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, options: [], range: range) {
                if let amountRange = Range(match.range(at: 1), in: text) {
                    let amountString = String(text[amountRange]).replacingOccurrences(of: ",", with: "")
                    return Decimal(string: amountString)
                }
            }
        }
        return nil
    }

    private static func extractDate(from text: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_AU")

        for pattern in datePatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, options: [], range: range) {
                if let fullRange = Range(match.range, in: text) {
                    let dateString = String(text[fullRange])

                    // Try various formats
                    for format in ["dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy", "dd/MM/yy", "dd MMM yyyy"] {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                    }
                }
            }
        }
        return nil
    }
}
```

---

## Camera Integration

### ReceiptCaptureView.swift

```swift
import SwiftUI
import AVFoundation

struct ReceiptCaptureView: View {
    @StateObject private var viewModel = ReceiptCaptureViewModel()
    @Environment(\.dismiss) private var dismiss

    var onCapture: (ReceiptData) -> Void

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()

            // Overlay
            VStack {
                Spacer()

                // Capture button
                Button(action: {
                    viewModel.capturePhoto()
                }) {
                    Circle()
                        .fill(.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(.gray, lineWidth: 3)
                                .frame(width: 60, height: 60)
                        )
                }
                .disabled(viewModel.isProcessing)
                .padding(.bottom, 30)
            }

            // Processing indicator
            if viewModel.isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView("Processing receipt...")
                    .tint(.white)
                    .foregroundColor(.white)
            }
        }
        .task {
            await viewModel.setupCamera()
            await viewModel.initializeOCR()
        }
        .onChange(of: viewModel.extractedData) { _, newValue in
            if let data = newValue {
                onCapture(data)
                dismiss()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}

@MainActor
class ReceiptCaptureViewModel: NSObject, ObservableObject {
    @Published var isProcessing = false
    @Published var extractedData: ReceiptData?
    @Published var error: String?

    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var ocrEngine: OCREngine?

    func setupCamera() async {
        guard await requestCameraPermission() else {
            error = "Camera permission required"
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = "Failed to access camera"
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        captureSession.commitConfiguration()

        Task.detached { [captureSession] in
            captureSession.startRunning()
        }
    }

    func initializeOCR() async {
        ocrEngine = OCREngine()
        do {
            try await ocrEngine?.initialize()
        } catch {
            self.error = "Failed to initialize OCR: \(error.localizedDescription)"
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}

extension ReceiptCaptureViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.error = error.localizedDescription
                return
            }

            guard let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData)?.cgImage else {
                self.error = "Failed to process photo"
                return
            }

            await processImage(image)
        }
    }

    @MainActor
    private func processImage(_ image: CGImage) async {
        isProcessing = true
        defer { isProcessing = false }

        guard let engine = ocrEngine else {
            error = "OCR not initialized"
            return
        }

        do {
            let results = try await engine.recognizeText(in: image)
            let receiptData = ReceiptDataExtractor.extract(from: results)
            extractedData = receiptData
        } catch {
            self.error = "OCR failed: \(error.localizedDescription)"
        }
    }
}

// Camera preview UIViewRepresentable
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
```

---

## Performance Optimization

### 1. Model Quantization

Reduce model size and improve inference speed:

```bash
# Quantize to INT8 (reduces size ~4x)
python -m onnxruntime.quantization.quantize \
    --input pp_ocrv4_det.onnx \
    --output pp_ocrv4_det_int8.onnx \
    --quant_format QDQ
```

### 2. CoreML Optimization

Enable CoreML for Neural Engine acceleration:

```swift
// In OCREngine.loadModels()
let sessionOptions = try ORTSessionOptions()

#if !targetEnvironment(simulator)
let coreMLOptions = ORTCoreMLExecutionProviderOptions()
coreMLOptions.enableOnSubgraphs = true
try sessionOptions.appendCoreMLExecutionProvider(with: coreMLOptions)
#endif
```

### 3. Image Preprocessing on GPU

Use Metal for faster image preprocessing:

```swift
import MetalPerformanceShaders

func preprocessWithMetal(_ image: CGImage, device: MTLDevice) -> Data? {
    // Use MPSImageScale for resizing
    // Use MPSImageConversion for format conversion
    // Much faster than CPU-based CGContext
}
```

### 4. Lazy Loading

Initialize OCR engine on first use:

```swift
actor OCREngineManager {
    static let shared = OCREngineManager()
    private var engine: OCREngine?

    func getEngine() async throws -> OCREngine {
        if let engine = engine {
            return engine
        }
        let newEngine = OCREngine()
        try await newEngine.initialize()
        engine = newEngine
        return newEngine
    }
}
```

---

## Testing Strategy

### Unit Tests

```swift
import XCTest
@testable import LocumTrackerOCR

final class ReceiptDataExtractorTests: XCTestCase {

    func testExtractTotal_Woolworths() {
        let ocrResults = [
            OCRResult(text: "WOOLWORTHS", boundingBox: .zero, confidence: 0.95),
            OCRResult(text: "Milk 2L  $3.50", boundingBox: .zero, confidence: 0.9),
            OCRResult(text: "Bread    $4.00", boundingBox: .zero, confidence: 0.9),
            OCRResult(text: "TOTAL    $7.50", boundingBox: .zero, confidence: 0.95),
            OCRResult(text: "GST      $0.68", boundingBox: .zero, confidence: 0.9)
        ]

        let result = ReceiptDataExtractor.extract(from: ocrResults)

        XCTAssertEqual(result.merchant, "Woolworths")
        XCTAssertEqual(result.totalAmount, Decimal(string: "7.50"))
        XCTAssertEqual(result.gstAmount, Decimal(string: "0.68"))
    }

    func testExtractDate_AustralianFormat() {
        let ocrResults = [
            OCRResult(text: "Date: 15/01/2026", boundingBox: .zero, confidence: 0.9)
        ]

        let result = ReceiptDataExtractor.extract(from: ocrResults)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: result.date!)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.year, 2026)
    }
}
```

### Integration Tests with Sample Receipts

```swift
final class OCREngineIntegrationTests: XCTestCase {
    var engine: OCREngine!

    override func setUp() async throws {
        engine = OCREngine()
        try await engine.initialize()
    }

    func testRecognizeWoolworthsReceipt() async throws {
        let image = loadTestImage("woolworths_receipt_sample")
        let results = try await engine.recognizeText(in: image)

        XCTAssertFalse(results.isEmpty)

        let fullText = results.map { $0.text }.joined(separator: " ")
        XCTAssertTrue(fullText.contains("WOOLWORTHS") || fullText.contains("Woolworths"))
    }

    private func loadTestImage(_ name: String) -> CGImage {
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: name, withExtension: "jpg")!
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        return CGImageSourceCreateImageAtIndex(source, 0, nil)!
    }
}
```

---

## Fallback Strategy

### iOS 26+ with Foundation Models

When available, use Apple's Foundation Models for better structured extraction:

```swift
import FoundationModels

@available(iOS 26, macOS 26, *)
@Generable
struct AppleReceiptData {
    @Guide("The merchant or store name from the receipt header")
    var merchant: String

    @Guide("Total amount paid, as a decimal number")
    var totalAmount: Double

    @Guide("GST/tax amount if shown")
    var gstAmount: Double?

    @Guide("Transaction date in ISO 8601 format")
    var date: String

    @Guide("Category: medical, transport, accommodation, meals, office, other")
    var category: String
}

@available(iOS 26, macOS 26, *)
func extractWithFoundationModels(ocrText: String) async throws -> AppleReceiptData {
    let session = LanguageModelSession()
    let prompt = "Extract receipt information from this text:\n\n\(ocrText)"
    let response = try await session.respond(to: prompt, generating: AppleReceiptData.self)
    return response.content
}
```

### Decision Logic

```swift
func extractReceiptData(from image: CGImage) async throws -> ReceiptData {
    // Step 1: Always run PaddleOCR for text extraction
    let ocrResults = try await ocrEngine.recognizeText(in: image)
    let rawText = ocrResults.map { $0.text }.joined(separator: "\n")

    // Step 2: Choose extraction method based on platform
    if #available(iOS 26, macOS 26, *) {
        // Use Foundation Models for structured extraction
        let appleData = try await extractWithFoundationModels(ocrText: rawText)
        return convertToReceiptData(appleData, rawText: rawText)
    } else {
        // Fall back to regex-based extraction
        return ReceiptDataExtractor.extract(from: ocrResults)
    }
}
```

---

## File Structure

```
Packages/LocumTrackerOCR/
├── Sources/
│   └── LocumTrackerOCR/
│       ├── OCREngine.swift
│       ├── ReceiptDataExtractor.swift
│       ├── ReceiptCaptureView.swift
│       ├── Models/
│       │   ├── OCRResult.swift
│       │   └── ReceiptData.swift
│       └── Resources/
│           └── OCRModels/
│               ├── pp_ocrv4_det.onnx
│               ├── pp_ocrv4_rec.onnx
│               └── ppocr_keys.txt
├── Tests/
│   └── LocumTrackerOCRTests/
│       ├── ReceiptDataExtractorTests.swift
│       ├── OCREngineTests.swift
│       └── Resources/
│           └── TestReceipts/
│               ├── woolworths_sample.jpg
│               ├── coles_sample.jpg
│               └── bp_sample.jpg
└── Package.swift
```

---

## Summary

| Aspect | Details |
|--------|---------|
| **OCR Engine** | PaddleOCR PP-OCRv4 via ONNX Runtime |
| **Model Size** | ~10 MB total (bundled in app) |
| **Runtime Size** | ~5-8 MB (ONNX Runtime Mobile) |
| **Platforms** | iOS 15+, macOS 12+ |
| **Acceleration** | CoreML on Neural Engine |
| **Offline** | Fully offline capable |
| **Fallback** | Apple Foundation Models on iOS 26+ |

