# On-Device Receipt Data Extraction: iOS and Android Options

*Research completed: January 2026*

This document evaluates on-device options for extracting structured data (merchant, amount, date, category) from receipt photos on iOS and Android devices.

---

## Executive Summary

| Platform | Recommended Primary Approach | Fallback/Alternative |
|----------|------------------------------|---------------------|
| **iOS** | Apple Foundation Models + Vision Framework | Vision Framework alone |
| **Android** | ML Kit GenAI (Gemini Nano) + ML Kit Text Recognition | PaddleOCR via ONNX Runtime |
| **Cross-platform** | PaddleOCR (ONNX) or Tesseract | Cloud API fallback |

---

## iOS Options

### 1. Apple Foundation Models Framework (iOS 26+) ⭐ RECOMMENDED

Apple's new on-device LLM framework, introduced at WWDC 2025, provides the most elegant solution for receipt parsing on iOS.

**Key Features:**
- ~3B parameter on-device language model
- **`@Generable` macro** for type-safe structured data extraction
- Combines seamlessly with Vision Framework OCR
- Complete privacy - data never leaves device
- No API costs

**How it works:**
```swift
import FoundationModels
import Vision

@Generable
struct ReceiptData {
    @Guide("The merchant or store name")
    var merchant: String

    @Guide("Total amount in decimal format")
    var amount: Decimal

    @Guide("Transaction date in ISO format")
    var date: Date

    @Guide("Category: food, transport, medical, office, other")
    var category: String
}

// 1. Use Vision to OCR the image
// 2. Pass OCR text to Foundation Models with @Generable struct
// 3. Get strongly-typed ReceiptData back
```

**Requirements:**
- iOS 26+ / iPadOS 26+ / macOS 26+
- A17 Pro, M1, or newer chip
- Apple Intelligence enabled

**Limitations:**
- Only available on newer devices (iPhone 15 Pro+, M1+ Macs/iPads)
- 3B model may struggle with very messy receipts
- No Android equivalent

**Sources:**
- [Apple Foundation Models Documentation](https://developer.apple.com/documentation/FoundationModels)
- [Apple Newsroom Announcement](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)
- [Exploring the Foundation Models Framework](https://www.createwithswift.com/exploring-the-foundation-models-framework/)

---

### 2. Vision Framework (iOS 13+)

Apple's mature OCR framework that works on all modern iOS devices.

**Key Classes:**
- `VNRecognizeTextRequest` - Text recognition
- `DataScannerViewController` (iOS 16+) - Live camera scanning
- `RecognizeDocumentsRequest` (iOS 26+) - Document structure recognition

**Strengths:**
- Works on all iOS devices back to iOS 13
- Excellent accuracy for printed text
- Fast on-device processing
- Ships with the OS - no dependencies

**Limitations:**
- Returns raw text only - requires custom parsing logic to extract structured fields
- No semantic understanding

**Implementation Pattern:**
1. Capture image via camera
2. Run `VNRecognizeTextRequest` to extract text
3. Apply regex/heuristics to find amounts, dates, merchant names
4. Or pass to Foundation Models for structured extraction (iOS 26+)

**Sources:**
- [VNRecognizeTextRequest Documentation](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [Structuring Recognized Text on a Document](https://developer.apple.com/documentation/visionkit/structuring_recognized_text_on_a_document)
- [WWDC25: Read documents using Vision](https://developer.apple.com/videos/play/wwdc2025/272/)

---

## Android Options

### 1. ML Kit GenAI + Text Recognition (Gemini Nano) ⭐ RECOMMENDED

Google's on-device GenAI APIs combine traditional OCR with Gemini Nano for intelligent parsing.

**Key APIs:**
- **ML Kit Text Recognition v2** - OCR (16.0.0+)
- **ML Kit GenAI Prompt API** - Gemini Nano access (Alpha)

**Recommended Pattern (from Google):**
> "Intelligent document scanning: Using a traditional ML model to extract text from a receipt, and then categorizing each item with Prompt API."

**Real-World Success:**
Kakao used this approach for parcel delivery, reducing order completion time by 24% and boosting conversion by 45%.

**Requirements:**
- Text Recognition: Any Android device with Google Play Services
- Gemini Nano: Pixel 9+ (nano-v2) or Pixel 10+ (nano-v3, best performance)

**Structured Output:**
Gemini Nano supports JSON schema for structured outputs, enabling type-safe extraction similar to Apple's `@Generable`.

**Limitations:**
- GenAI Prompt API still in Alpha (as of late 2025)
- Best performance only on Pixel 10 devices
- Requires Google Play Services

**Sources:**
- [ML Kit Text Recognition v2](https://developers.google.com/ml-kit/vision/text-recognition/v2)
- [On-device GenAI APIs with Gemini Nano](https://android-developers.googleblog.com/2025/05/on-device-gen-ai-apis-ml-kit-gemini-nano.html)
- [ML Kit GenAI Prompt API Alpha](https://android-developers.googleblog.com/2025/10/ml-kit-genai-prompt-api-alpha-release.html)

---

### 2. ML Kit Text Recognition v2 (Standalone)

Google's on-device OCR without the GenAI component.

**Features:**
- 300+ language support including Chinese, Japanese, Korean
- ~200ms latency on typical receipts
- Works offline
- No Firebase dependency required

**Dependencies:**
```gradle
implementation 'com.google.mlkit:text-recognition:16.0.0'
```

**Strengths:**
- Works on virtually all Android devices
- Well-documented, stable API
- Good accuracy on clear receipts

**Limitations:**
- Raw text output requires custom parsing
- Accuracy drops on poor-quality images or stylized fonts

**Sources:**
- [ML Kit Text Recognition Android Guide](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)
- [ML Kit for Fast On-Device Text Recognition](https://softwarehouse.au/blog/harnessing-ml-kit-for-fast-accurate-on-device-text-recognition/)

---

### 3. PaddleOCR via ONNX Runtime

Open-source alternative that avoids Google Play Services dependency.

**2025 Status:**
- PaddleOCR v3.0 released May 2025
- PP-OCRv5 with 13% accuracy improvement
- Supports 109 languages

**Mobile Implementation (Ente's approach):**
- Export models to ONNX format
- Use ONNX Runtime Mobile for inference
- Rebuild pre/post-processing in Kotlin
- Wrap in Flutter plugin for cross-platform

**Strengths:**
- Fully open-source
- No Google Play Services required
- Excellent accuracy on receipts, invoices, multi-language documents
- Handles rotated documents well

**Limitations:**
- More complex integration than ML Kit
- Requires bundling models with app (~8-15MB)
- Less documentation for mobile

**Sources:**
- [PaddleOCR GitHub](https://github.com/PaddlePaddle/PaddleOCR)
- [Ente's Open-Source Android OCR](https://ente.io/blog/ocr/)
- [PaddleOCR Mobile Deployment Guide](https://paddlepaddle.github.io/PaddleOCR/main/en/version2.x/legacy/lite.html)

---

### 4. Tesseract OCR

Classic open-source OCR engine.

**Mobile Wrappers:**
- Android: `Tesseract4Android`
- iOS: `TesseractOCRiOS`

**Performance (2025 benchmarks):**
- ~220ms average latency
- Good on clean printed text
- Struggles with cursive/stylized fonts

**Strengths:**
- Battle-tested, widely used
- MIT/Apache licensed
- Trainable for custom fonts

**Limitations:**
- Lower accuracy than ML Kit or PaddleOCR on receipts
- Steep learning curve for configuration
- Larger language data files

**Sources:**
- [Tesseract OCR iOS](https://github.com/gali8/Tesseract-OCR-iOS)
- [Implementing OCR in Android/iOS with Open-Source SDKs](https://transloadit.com/devtips/implementing-ocr-in-android-and-ios-apps-with-open-source-sdks/)

---

## Cross-Platform Approaches

### Option A: Platform-Native (Recommended)

Use the best tool on each platform:
- **iOS**: Vision Framework + Foundation Models (iOS 26+)
- **Android**: ML Kit Text Recognition + GenAI Prompt API

**Pros:** Best accuracy and performance on each platform
**Cons:** Different codebases for OCR/parsing logic

### Option B: PaddleOCR Everywhere

Use PaddleOCR via ONNX Runtime on both platforms.

**Pros:** Consistent behavior, fully open-source
**Cons:** More integration work, larger app size

### Option C: Hybrid with Cloud Fallback

Use on-device OCR with cloud LLM fallback for parsing.

```
1. Capture receipt image
2. Run on-device OCR (Vision/ML Kit)
3. Attempt local parsing with heuristics
4. If confidence low, send text to cloud LLM (Claude/GPT) for extraction
```

**Pros:** Works on all devices, high accuracy
**Cons:** Requires internet for fallback, API costs

---

## Recommended Implementation for LocumTracker

Given the project requirements (Australian locum doctors, receipt management), here's the recommended approach:

### iOS Implementation

```swift
// Phase 1: Vision Framework (works on all devices)
func extractTextFromReceipt(image: CGImage) async -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // ... perform request and return recognized text
}

// Phase 2: Foundation Models parsing (iOS 26+ only)
@Generable
struct ReceiptExtraction {
    @Guide("Business or merchant name from the receipt")
    var merchant: String

    @Guide("Total amount paid as decimal number")
    var totalAmount: Decimal

    @Guide("Date of transaction")
    var date: Date

    @Guide("Category: medical, transport, accommodation, meals, equipment, other")
    var category: String

    @Guide("GST amount if shown, otherwise nil")
    var gstAmount: Decimal?
}

// Fallback: Regex-based parsing for older devices
func parseReceiptText(_ text: String) -> ReceiptExtraction? {
    // Regex patterns for Australian receipts:
    // - Total: /TOTAL\s*\$?([\d,]+\.\d{2})/i
    // - Date: /(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/
    // - GST: /GST\s*\$?([\d,]+\.\d{2})/i
}
```

### Android Implementation (Future)

```kotlin
// ML Kit Text Recognition
val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

// For Pixel 9+ with Gemini Nano
val promptApi = MlKitGenAi.getPromptApi(context)
val result = promptApi.generateContent(
    "Extract merchant, amount, date from this receipt text: $ocrText"
)
```

### Data Model (already in LocumTrackerCore)

The existing `Receipt` model should be extended:

```swift
@Model
class Receipt {
    var image: Data?
    var extractedText: String?      // Raw OCR output
    var merchant: String?           // Extracted merchant name
    var amount: Decimal             // Total amount
    var date: Date                  // Transaction date
    var category: ReceiptCategory   // Categorization
    var gstAmount: Decimal?         // GST if applicable
    var confidence: Double?         // Extraction confidence (0-1)
    var manuallyVerified: Bool      // User has confirmed data
}
```

---

## Performance Considerations

| Approach | Latency | Accuracy | Offline | Model Size |
|----------|---------|----------|---------|------------|
| Vision + Foundation Models | ~1-2s | High | ✅ | Built-in |
| Vision alone + regex | ~200ms | Medium | ✅ | Built-in |
| ML Kit + Gemini Nano | ~1-2s | High | ✅ | Downloaded |
| ML Kit alone + regex | ~200ms | Medium | ✅ | ~10MB |
| PaddleOCR (ONNX) | ~300ms | High | ✅ | ~15MB |
| Tesseract | ~220ms | Medium | ✅ | ~15-30MB |

---

## Privacy Considerations

All recommended approaches process data **entirely on-device**:
- No receipt images sent to cloud servers
- No text transmitted over network
- Compliant with medical privacy requirements (important for locum doctors)
- Works offline in remote/rural areas (MMM 5-7 locations)

---

## Next Steps

1. **iOS (immediate)**: Implement Vision Framework OCR in existing app
2. **iOS (iOS 26 release)**: Add Foundation Models integration with `@Generable`
3. **Android (future)**: Start with ML Kit Text Recognition, add GenAI when stable
4. **Testing**: Build test suite with sample Australian receipts (Woolworths, Coles, BP, pharmacies, medical suppliers)

---

## References

### Apple
- [Foundation Models Documentation](https://developer.apple.com/documentation/FoundationModels)
- [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [VisionKit Documentation](https://developer.apple.com/documentation/visionkit)
- [WWDC25: Read documents using Vision](https://developer.apple.com/videos/play/wwdc2025/272/)

### Google/Android
- [ML Kit Text Recognition v2](https://developers.google.com/ml-kit/vision/text-recognition/v2)
- [ML Kit GenAI APIs Overview](https://developers.google.com/ml-kit/genai)
- [Gemini Nano on Android](https://android-developers.googleblog.com/2025/05/on-device-gen-ai-apis-ml-kit-gemini-nano.html)

### Open Source
- [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR)
- [Tesseract OCR](https://github.com/tesseract-ocr)
- [Ente's Open-Source OCR](https://ente.io/blog/ocr/)

### On-Device LLMs
- [MLC-LLM](https://www.callstack.com/blog/want-to-run-llms-on-your-device-meet-mlc)
- [ExecuTorch](https://unsloth.ai/docs/basics/deploy-llms-phone)
- [Google MediaPipe LLM Inference](https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/ios)
