# PaddleOCR Implementation Guide: iOS and macOS

*Implementation planning document for LocumTracker*

This guide details how to integrate PaddleOCR for on-device receipt text extraction on iOS and macOS using ONNX Runtime.

## Architecture

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

## Implementation Phases

| Phase | Document | Description |
|-------|----------|-------------|
| 1 | [01_model_preparation.md](01_model_preparation.md) | Download and convert PaddleOCR models to ONNX |
| 2 | [02_project_setup.md](02_project_setup.md) | Configure SPM/CocoaPods and add models to Xcode |
| 3 | [03_core_implementation.md](03_core_implementation.md) | OCREngine with detection and recognition |
| 4 | [04_camera_integration.md](04_camera_integration.md) | Camera capture view for iOS |
| 5 | [05_receipt_extraction.md](05_receipt_extraction.md) | Receipt data extraction with regex patterns |
| 6 | [06_optimization_testing.md](06_optimization_testing.md) | Performance optimization, testing, and fallback strategy |

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
