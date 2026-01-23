# Phase 6: Optimization, Testing, and Fallback Strategy

Performance optimization, testing patterns, and fallback strategy for iOS 26+.

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

**Previous:** [05_receipt_extraction.md](05_receipt_extraction.md)
**Back to:** [OVERVIEW.md](OVERVIEW.md)
