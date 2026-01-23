# PaddleOCR Implementation Guide: Android

*Implementation planning document for LocumTracker*

This guide details how to integrate PaddleOCR for on-device receipt text extraction on Android using ONNX Runtime.

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
10. [Alternative: Paddle-Lite](#alternative-paddle-lite)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    LocumTracker Android App                     │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │  CameraX    │───▶│  OCR Engine │───▶│  Receipt Parser     │  │
│  │   Capture   │    │  (PaddleOCR)│    │  (Regex/Gemini)     │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
│         │                  │                      │              │
│         ▼                  ▼                      ▼              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │   Bitmap    │    │ ONNX Runtime│    │   ReceiptData       │  │
│  │             │    │   + Models  │    │   (Structured)      │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

Models bundled in assets (~10MB total):
- pp_ocrv4_det.onnx (Text Detection)
- pp_ocrv4_rec.onnx (Text Recognition)
- ppocr_keys.txt (Character dictionary)
```

### Why ONNX Runtime?

1. **No Google Play Services dependency** - Works on all Android devices
2. **NNAPI Support** - Hardware acceleration on supported devices
3. **Cross-platform** - Same models work on iOS/macOS
4. **Open Source** - MIT licensed, actively maintained by Microsoft
5. **Smaller than Paddle-Lite** - Simpler integration

---

## Prerequisites

### Development Environment

- Android Studio Hedgehog (2023.1.1) or later
- Kotlin 1.9+
- Gradle 8.0+
- JDK 17+

### Target Platforms

| API Level | Android Version | Support |
|-----------|-----------------|---------|
| 24 (minimum) | Android 7.0 | Basic |
| 26+ | Android 8.0+ | NNAPI acceleration |
| 29+ | Android 10+ | Recommended |

### Dependencies Overview

```
ONNX Runtime Mobile: ~5-8 MB
PaddleOCR Models: ~10 MB
CameraX: ~2 MB
Total APK increase: ~15-20 MB
```

---

## Model Preparation

### Step 1: Download and Convert Models

```bash
#!/bin/bash
# prepare_models.sh

# Create output directory
mkdir -p app/src/main/assets/ocr_models

# Install conversion tools
pip install paddle2onnx paddlepaddle

# Download PP-OCRv4 mobile models
wget https://paddleocr.bj.bcebos.com/PP-OCRv4/english/en_PP-OCRv4_det_infer.tar
wget https://paddleocr.bj.bcebos.com/PP-OCRv4/english/en_PP-OCRv4_rec_infer.tar

# Extract
tar -xf en_PP-OCRv4_det_infer.tar
tar -xf en_PP-OCRv4_rec_infer.tar

# Convert detection model to ONNX
paddle2onnx --model_dir en_PP-OCRv4_det_infer \
    --model_filename inference.pdmodel \
    --params_filename inference.pdiparams \
    --save_file app/src/main/assets/ocr_models/pp_ocrv4_det.onnx \
    --opset_version 12 \
    --input_shape_dict="{'x':[-1,3,-1,-1]}"

# Convert recognition model to ONNX
paddle2onnx --model_dir en_PP-OCRv4_rec_infer \
    --model_filename inference.pdmodel \
    --params_filename inference.pdiparams \
    --save_file app/src/main/assets/ocr_models/pp_ocrv4_rec.onnx \
    --opset_version 12 \
    --input_shape_dict="{'x':[-1,3,-1,-1]}"

# Download character dictionary
wget https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/main/ppocr/utils/en_dict.txt \
    -O app/src/main/assets/ocr_models/ppocr_keys.txt

# Cleanup
rm -rf en_PP-OCRv4_det_infer en_PP-OCRv4_rec_infer *.tar

echo "Models prepared successfully!"
ls -la app/src/main/assets/ocr_models/
```

### Step 2: Verify Model Files

```
app/src/main/assets/ocr_models/
├── pp_ocrv4_det.onnx      (~3.5 MB)
├── pp_ocrv4_rec.onnx      (~4.5 MB)
└── ppocr_keys.txt         (~50 KB for English)
```

---

## Project Setup

### build.gradle.kts (Module: app)

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.locumtracker.android"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.locumtracker.android"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        // Don't compress ONNX models
        androidResources {
            noCompress += listOf("onnx")
        }
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.8"
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // ONNX Runtime
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.16.3")
    // Or for smaller size (limited operators):
    // implementation("com.microsoft.onnxruntime:onnxruntime-mobile:1.16.3")

    // CameraX
    val cameraxVersion = "1.3.1"
    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    implementation("androidx.camera:camera-view:$cameraxVersion")

    // Compose
    implementation(platform("androidx.compose:compose-bom:2024.01.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Permissions
    implementation("com.google.accompanist:accompanist-permissions:0.34.0")

    // Material Icons Extended (for Icons.Default)
    implementation("androidx.compose.material:material-icons-extended")

    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}
```

### AndroidManifest.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Camera permission -->
    <uses-feature android:name="android.hardware.camera" android:required="true" />
    <uses-permission android:name="android.permission.CAMERA" />

    <application
        android:name=".LocumTrackerApplication"
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/Theme.LocumTracker"
        android:largeHeap="true">

        <!-- largeHeap helps with model loading on low-memory devices -->

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

---

## Core Implementation

### OCREngine.kt - Main OCR Interface

```kotlin
package com.locumtracker.ocr

import android.content.Context
import android.graphics.Bitmap
import android.graphics.RectF
import ai.onnxruntime.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.nio.FloatBuffer
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/**
 * Constants for OCR processing parameters
 */
private object OCRConstants {
    /** Multiple for padding detection input (PaddleOCR requirement) */
    const val DETECTION_PADDING_MULTIPLE = 32

    /** Target height for recognition model input */
    const val RECOGNITION_TARGET_HEIGHT = 48

    /** Minimum width for recognition model input */
    const val RECOGNITION_MIN_WIDTH = 48

    /** Maximum width for recognition model input */
    const val RECOGNITION_MAX_WIDTH = 320

    /** Minimum box dimension to filter noise */
    const val MINIMUM_BOX_DIMENSION = 5

    /** Threshold for considering text on the same line (in pixels) */
    const val SAME_LINE_THRESHOLD = 20f

    /** Padding expansion for cropped text regions (in pixels) */
    const val TEXT_REGION_PADDING = 2f

    /** Number of threads for inference */
    const val INFERENCE_THREAD_COUNT = 4

    /** ImageNet normalization mean values (RGB) */
    val NORMALIZATION_MEAN = floatArrayOf(0.485f, 0.456f, 0.406f)

    /** ImageNet normalization standard deviation values (RGB) */
    val NORMALIZATION_STD = floatArrayOf(0.229f, 0.224f, 0.225f)

    /** Recognition normalization offset */
    const val RECOGNITION_NORM_OFFSET = 0.5f

    /** Detection model input tensor name */
    const val DETECTION_INPUT_NAME = "x"

    /** Recognition model input tensor name */
    const val RECOGNITION_INPUT_NAME = "x"

    /** Bytes per pixel for ARGB format */
    const val BYTES_PER_PIXEL = 4
}

/**
 * Configuration for OCR processing
 */
data class OCRConfiguration(
    /** Maximum image dimension (larger images will be scaled down) */
    val maxImageSize: Int = 960,
    /** Detection confidence threshold (0-1) */
    val detectionThreshold: Float = 0.3f,
    /** Recognition confidence threshold (0-1) */
    val recognitionThreshold: Float = 0.5f,
    /** Use NNAPI execution provider if available */
    val useNNAPI: Boolean = true
)

/**
 * Result of text recognition for a single text region
 */
data class OCRResult(
    /** Recognized text */
    val text: String,
    /** Bounding box in original image coordinates */
    val boundingBox: RectF,
    /** Recognition confidence (0-1) */
    val confidence: Float
)

/**
 * Errors that can occur during OCR processing
 */
sealed class OCRError : Exception() {
    data class ModelLoadFailed(override val message: String) : OCRError()
    object ImagePreprocessingFailed : OCRError()
    data class InferenceError(override val message: String) : OCRError()
    object NotInitialized : OCRError()
}

/**
 * Main OCR engine using PaddleOCR models via ONNX Runtime
 */
class OCREngine(
    private val context: Context,
    private val configuration: OCRConfiguration = OCRConfiguration()
) {
    private var ortEnvironment: OrtEnvironment? = null
    private var detectionSession: OrtSession? = null
    private var recognitionSession: OrtSession? = null
    private var characterDictionary: List<String> = emptyList()

    private var isInitialized = false

    /**
     * Initialize the OCR engine by loading models.
     * Call this once at app startup or before first use.
     */
    suspend fun initialize() = withContext(Dispatchers.IO) {
        try {
            ortEnvironment = OrtEnvironment.getEnvironment()
            loadModels()
            loadDictionary()
            isInitialized = true
        } catch (e: Exception) {
            throw OCRError.ModelLoadFailed("Failed to initialize OCR: ${e.message}")
        }
    }

    /**
     * Release resources when done
     */
    fun release() {
        detectionSession?.close()
        recognitionSession?.close()
        ortEnvironment?.close()
        isInitialized = false
    }

    private fun loadModels() {
        val env = ortEnvironment ?: throw OCRError.NotInitialized

        // Configure session options
        val sessionOptions = OrtSession.SessionOptions().apply {
            setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            setIntraOpNumThreads(OCRConstants.INFERENCE_THREAD_COUNT)

            // Enable NNAPI if configured
            if (configuration.useNNAPI) {
                try {
                    addNnapi()
                } catch (e: Exception) {
                    // NNAPI not available, fall back to CPU
                }
            }
        }

        // Load detection model from assets
        val detModelBytes = context.assets.open("ocr_models/pp_ocrv4_det.onnx").readBytes()
        detectionSession = env.createSession(detModelBytes, sessionOptions)

        // Load recognition model from assets
        val recModelBytes = context.assets.open("ocr_models/pp_ocrv4_rec.onnx").readBytes()
        recognitionSession = env.createSession(recModelBytes, sessionOptions)
    }

    private fun loadDictionary() {
        val dictContent = context.assets.open("ocr_models/ppocr_keys.txt")
            .bufferedReader()
            .readLines()
            .filter { it.isNotEmpty() }

        // Add blank token at the beginning (CTC blank)
        characterDictionary = listOf(" ") + dictContent
    }

    /**
     * Recognize text in a bitmap image
     * @param bitmap Bitmap to process
     * @return List of recognized text regions with bounding boxes and confidence
     */
    suspend fun recognizeText(bitmap: Bitmap): List<OCRResult> = withContext(Dispatchers.Default) {
        if (!isInitialized) {
            throw OCRError.NotInitialized
        }

        processImage(bitmap)
    }

    private fun processImage(bitmap: Bitmap): List<OCRResult> {
        // Step 1: Preprocess image for detection
        val (detInput, scale, targetWidth, targetHeight) = preprocessForDetection(bitmap)

        // Step 2: Run text detection
        val textBoxes = runDetection(
            input = detInput,
            width = targetWidth,
            height = targetHeight,
            originalWidth = bitmap.width,
            originalHeight = bitmap.height,
            scale = scale
        )

        // Step 3: For each detected box, crop and run recognition
        val results = mutableListOf<OCRResult>()

        for (box in textBoxes) {
            val croppedBitmap = cropTextRegion(bitmap, box) ?: continue
            val recInput = preprocessForRecognition(croppedBitmap)
            val (text, confidence) = runRecognition(recInput, croppedBitmap.width)

            if (confidence >= configuration.recognitionThreshold && text.isNotEmpty()) {
                results.add(OCRResult(
                    text = text,
                    boundingBox = box,
                    confidence = confidence
                ))
            }

            croppedBitmap.recycle()
        }

        // Sort results top-to-bottom, left-to-right
        results.sortWith { a, b ->
            val yDiff = kotlin.math.abs(a.boundingBox.top - b.boundingBox.top)
            if (yDiff < OCRConstants.SAME_LINE_THRESHOLD) {
                a.boundingBox.left.compareTo(b.boundingBox.left)
            } else {
                a.boundingBox.top.compareTo(b.boundingBox.top)
            }
        }

        return results
    }

    // MARK: - Detection

    private data class DetectionInput(
        val data: FloatBuffer,
        val scale: Float,
        val targetWidth: Int,
        val targetHeight: Int
    )

    private fun preprocessForDetection(bitmap: Bitmap): DetectionInput {
        val originalWidth = bitmap.width.toFloat()
        val originalHeight = bitmap.height.toFloat()

        // Calculate scale to fit within max size
        var scale = 1.0f
        val maxDim = max(originalWidth, originalHeight)
        if (maxDim > configuration.maxImageSize) {
            scale = configuration.maxImageSize / maxDim
        }

        val scaledWidth = (originalWidth * scale).toInt()
        val scaledHeight = (originalHeight * scale).toInt()

        // Round to multiple of padding requirement (required by detection model)
        val paddingMultiple = OCRConstants.DETECTION_PADDING_MULTIPLE.toDouble()
        val targetWidth = (ceil(scaledWidth / paddingMultiple) * paddingMultiple).toInt()
        val targetHeight = (ceil(scaledHeight / paddingMultiple) * paddingMultiple).toInt()

        // Create resized bitmap
        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, scaledWidth, scaledHeight, true)

        // Create padded bitmap
        val paddedBitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(paddedBitmap)
        canvas.drawColor(android.graphics.Color.WHITE)
        canvas.drawBitmap(resizedBitmap, 0f, 0f, null)
        resizedBitmap.recycle()

        // Convert to normalized float tensor [1, 3, H, W]
        val pixels = IntArray(targetWidth * targetHeight)
        paddedBitmap.getPixels(pixels, 0, targetWidth, 0, 0, targetWidth, targetHeight)
        paddedBitmap.recycle()

        // PaddleOCR uses ImageNet normalization
        val mean = OCRConstants.NORMALIZATION_MEAN
        val std = OCRConstants.NORMALIZATION_STD

        val floatBuffer = FloatBuffer.allocate(3 * targetWidth * targetHeight)
        val hw = targetWidth * targetHeight

        // Store in CHW format (channels first)
        for (c in 0 until 3) {
            for (i in 0 until hw) {
                val pixel = pixels[i]
                val value = when (c) {
                    0 -> ((pixel shr 16) and 0xFF) / 255.0f  // R
                    1 -> ((pixel shr 8) and 0xFF) / 255.0f   // G
                    2 -> (pixel and 0xFF) / 255.0f          // B
                    else -> 0f
                }
                floatBuffer.put((value - mean[c]) / std[c])
            }
        }
        floatBuffer.rewind()

        return DetectionInput(floatBuffer, scale, targetWidth, targetHeight)
    }

    private fun runDetection(
        input: FloatBuffer,
        width: Int,
        height: Int,
        originalWidth: Int,
        originalHeight: Int,
        scale: Float
    ): List<RectF> {
        val session = detectionSession ?: throw OCRError.NotInitialized
        val env = ortEnvironment ?: throw OCRError.NotInitialized

        val inputShape = longArrayOf(1, 3, height.toLong(), width.toLong())
        val inputTensor = OnnxTensor.createTensor(env, input, inputShape)

        val outputs = session.run(mapOf(OCRConstants.DETECTION_INPUT_NAME to inputTensor))
        inputTensor.close()

        val outputTensor = outputs[0] as OnnxTensor
        val outputData = outputTensor.floatBuffer

        val boxes = postProcessDetection(
            outputData = outputData,
            width = width,
            height = height,
            originalWidth = originalWidth,
            originalHeight = originalHeight,
            scale = scale,
            threshold = configuration.detectionThreshold
        )

        outputTensor.close()
        outputs.close()

        return boxes
    }

    private fun postProcessDetection(
        outputData: FloatBuffer,
        width: Int,
        height: Int,
        originalWidth: Int,
        originalHeight: Int,
        scale: Float,
        threshold: Float
    ): List<RectF> {
        // Binary threshold the probability map
        val binaryMap = BooleanArray(width * height)
        for (i in 0 until min(outputData.capacity(), width * height)) {
            binaryMap[i] = outputData.get(i) > threshold
        }

        // Find connected components (simple flood fill)
        val visited = BooleanArray(width * height)
        val boxes = mutableListOf<RectF>()

        for (y in 0 until height) {
            for (x in 0 until width) {
                val idx = y * width + x
                if (binaryMap[idx] && !visited[idx]) {
                    // Flood fill to find bounding box
                    var minX = x
                    var maxX = x
                    var minY = y
                    var maxY = y

                    val stack = ArrayDeque<Pair<Int, Int>>()
                    stack.add(x to y)

                    while (stack.isNotEmpty()) {
                        val (cx, cy) = stack.removeLast()
                        if (cx < 0 || cx >= width || cy < 0 || cy >= height) continue

                        val cidx = cy * width + cx
                        if (visited[cidx] || !binaryMap[cidx]) continue

                        visited[cidx] = true
                        minX = min(minX, cx)
                        maxX = max(maxX, cx)
                        minY = min(minY, cy)
                        maxY = max(maxY, cy)

                        stack.add(cx + 1 to cy)
                        stack.add(cx - 1 to cy)
                        stack.add(cx to cy + 1)
                        stack.add(cx to cy - 1)
                    }

                    // Filter small boxes (likely noise)
                    val boxWidth = maxX - minX
                    val boxHeight = maxY - minY
                    if (boxWidth > OCRConstants.MINIMUM_BOX_DIMENSION && boxHeight > OCRConstants.MINIMUM_BOX_DIMENSION) {
                        // Convert back to original image coordinates
                        boxes.add(RectF(
                            minX / scale,
                            minY / scale,
                            maxX / scale,
                            maxY / scale
                        ))
                    }
                }
            }
        }

        return boxes
    }

    // MARK: - Recognition

    private fun cropTextRegion(bitmap: Bitmap, box: RectF): Bitmap? {
        // Expand box slightly for better recognition
        val padding = OCRConstants.TEXT_REGION_PADDING
        val left = max(0f, box.left - padding).toInt()
        val top = max(0f, box.top - padding).toInt()
        val right = min(bitmap.width.toFloat(), box.right + padding).toInt()
        val bottom = min(bitmap.height.toFloat(), box.bottom + padding).toInt()

        val width = right - left
        val height = bottom - top

        if (width <= 0 || height <= 0) return null

        return try {
            Bitmap.createBitmap(bitmap, left, top, width, height)
        } catch (e: Exception) {
            null
        }
    }

    private fun preprocessForRecognition(bitmap: Bitmap): FloatBuffer {
        // Target height is fixed, width is variable based on aspect ratio
        val targetHeight = OCRConstants.RECOGNITION_TARGET_HEIGHT
        val aspectRatio = bitmap.width.toFloat() / bitmap.height.toFloat()
        val targetWidth = max(
            OCRConstants.RECOGNITION_MIN_WIDTH,
            min(OCRConstants.RECOGNITION_MAX_WIDTH, (targetHeight * aspectRatio).toInt())
        )

        // Resize
        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)

        // Convert to float tensor normalized to [-1, 1]
        val pixels = IntArray(targetWidth * targetHeight)
        resizedBitmap.getPixels(pixels, 0, targetWidth, 0, 0, targetWidth, targetHeight)
        resizedBitmap.recycle()

        val floatBuffer = FloatBuffer.allocate(3 * targetWidth * targetHeight)
        val hw = targetWidth * targetHeight

        for (c in 0 until 3) {
            for (i in 0 until hw) {
                val pixel = pixels[i]
                val value = when (c) {
                    0 -> ((pixel shr 16) and 0xFF) / 255.0f
                    1 -> ((pixel shr 8) and 0xFF) / 255.0f
                    2 -> (pixel and 0xFF) / 255.0f
                    else -> 0f
                }
                // Normalize to [-1, 1] range
                floatBuffer.put((value - OCRConstants.RECOGNITION_NORM_OFFSET) / OCRConstants.RECOGNITION_NORM_OFFSET)
            }
        }
        floatBuffer.rewind()

        return floatBuffer
    }

    private fun runRecognition(input: FloatBuffer, inputWidth: Int): Pair<String, Float> {
        val session = recognitionSession ?: throw OCRError.NotInitialized
        val env = ortEnvironment ?: throw OCRError.NotInitialized

        val targetHeight = OCRConstants.RECOGNITION_TARGET_HEIGHT
        val targetWidth = max(
            OCRConstants.RECOGNITION_MIN_WIDTH,
            min(OCRConstants.RECOGNITION_MAX_WIDTH, inputWidth)
        )

        val inputShape = longArrayOf(1, 3, targetHeight.toLong(), targetWidth.toLong())
        val inputTensor = OnnxTensor.createTensor(env, input, inputShape)

        val outputs = session.run(mapOf(OCRConstants.RECOGNITION_INPUT_NAME to inputTensor))
        inputTensor.close()

        val outputTensor = outputs[0] as OnnxTensor
        val outputShape = outputTensor.info.shape
        val outputData = outputTensor.floatBuffer

        val result = decodeCTCOutput(outputData, outputShape)

        outputTensor.close()
        outputs.close()

        return result
    }

    private fun decodeCTCOutput(outputData: FloatBuffer, shape: LongArray): Pair<String, Float> {
        // Shape is [1, T, num_classes]
        if (shape.size != 3) return "" to 0f

        val seqLength = shape[1].toInt()
        val numClasses = shape[2].toInt()

        val result = StringBuilder()
        var totalConfidence = 0f
        var charCount = 0
        var lastIndex = -1

        for (t in 0 until seqLength) {
            var maxProb = 0f
            var maxIndex = 0

            for (c in 0 until numClasses) {
                val prob = outputData.get(t * numClasses + c)
                if (prob > maxProb) {
                    maxProb = prob
                    maxIndex = c
                }
            }

            // CTC decoding: skip blanks (index 0) and repeated characters
            if (maxIndex != 0 && maxIndex != lastIndex) {
                if (maxIndex < characterDictionary.size) {
                    result.append(characterDictionary[maxIndex])
                    totalConfidence += maxProb
                    charCount++
                }
            }
            lastIndex = maxIndex
        }

        val avgConfidence = if (charCount > 0) totalConfidence / charCount else 0f
        return result.toString() to avgConfidence
    }
}
```

### ReceiptDataExtractor.kt - Structured Data Extraction

```kotlin
package com.locumtracker.ocr

import java.math.BigDecimal
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.regex.Pattern

/**
 * Extracted receipt data
 */
data class ReceiptData(
    val merchant: String? = null,
    val totalAmount: BigDecimal? = null,
    val subtotal: BigDecimal? = null,
    val gstAmount: BigDecimal? = null,
    val date: LocalDate? = null,
    val rawText: String,
    val confidence: Float
)

/**
 * Processes OCR results to extract structured receipt data
 */
object ReceiptDataExtractor {

    // Regex patterns for Australian receipts
    private val totalPatterns = listOf(
        Pattern.compile("""(?:TOTAL|Total|AMOUNT DUE|Balance Due|TO PAY)[:\s]*\$?\s*([\d,]+\.\d{2})""", Pattern.CASE_INSENSITIVE),
        Pattern.compile("""(?:EFTPOS|CARD|VISA|MASTERCARD|PAID)[:\s]*\$?\s*([\d,]+\.\d{2})""", Pattern.CASE_INSENSITIVE),
        Pattern.compile("""\$\s*([\d,]+\.\d{2})\s*(?:TOTAL|AUD)?""", Pattern.CASE_INSENSITIVE)
    )

    private val gstPatterns = listOf(
        Pattern.compile("""(?:GST|G\.S\.T\.|TAX)[:\s]*\$?\s*([\d,]+\.\d{2})""", Pattern.CASE_INSENSITIVE),
        Pattern.compile("""(?:Includes GST of|GST Included)[:\s]*\$?\s*([\d,]+\.\d{2})""", Pattern.CASE_INSENSITIVE)
    )

    private val datePatterns = listOf(
        Pattern.compile("""(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})"""),
        Pattern.compile("""(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{2,4})""", Pattern.CASE_INSENSITIVE)
    )

    private val abnPattern = Pattern.compile("""ABN[:\s]*(\d{2}\s*\d{3}\s*\d{3}\s*\d{3})""", Pattern.CASE_INSENSITIVE)

    // Common Australian merchants
    private val knownMerchants = listOf(
        "WOOLWORTHS", "COLES", "ALDI", "IGA", "COSTCO",
        "BUNNINGS", "OFFICEWORKS", "JB HI-FI", "KMART", "TARGET", "BIG W",
        "BP", "SHELL", "CALTEX", "7-ELEVEN", "AMPOL",
        "CHEMIST WAREHOUSE", "PRICELINE", "TERRY WHITE",
        "MCDONALD'S", "SUBWAY", "KFC", "HUNGRY JACK'S"
    )

    /**
     * Extract structured data from OCR results
     */
    fun extract(ocrResults: List<OCRResult>): ReceiptData {
        val fullText = ocrResults.joinToString("\n") { it.text }
        val avgConfidence = if (ocrResults.isEmpty()) 0f
            else ocrResults.map { it.confidence }.average().toFloat()

        return ReceiptData(
            merchant = extractMerchant(ocrResults),
            totalAmount = extractTotal(fullText),
            gstAmount = extractGST(fullText),
            date = extractDate(fullText),
            rawText = fullText,
            confidence = avgConfidence
        )
    }

    private fun extractMerchant(results: List<OCRResult>): String? {
        // Take first 5 lines as candidates
        val topLines = results.take(5).map { it.text.uppercase().trim() }

        // Check for known merchants
        for (line in topLines) {
            for (merchant in knownMerchants) {
                if (line.contains(merchant)) {
                    return merchant.lowercase()
                        .replaceFirstChar { it.uppercase() }
                }
            }
        }

        // Return first non-empty, non-numeric line
        for (line in topLines) {
            val cleaned = line.trim()
            if (cleaned.isNotEmpty() && !cleaned.all { it.isDigit() || it == ' ' }) {
                return cleaned.lowercase()
                    .split(" ")
                    .joinToString(" ") { word ->
                        word.replaceFirstChar { it.uppercase() }
                    }
            }
        }

        return null
    }

    private fun extractTotal(text: String): BigDecimal? {
        for (pattern in totalPatterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val amountString = matcher.group(1)?.replace(",", "")
                return try {
                    BigDecimal(amountString)
                } catch (e: Exception) {
                    null
                }
            }
        }
        return null
    }

    private fun extractGST(text: String): BigDecimal? {
        for (pattern in gstPatterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val amountString = matcher.group(1)?.replace(",", "")
                return try {
                    BigDecimal(amountString)
                } catch (e: Exception) {
                    null
                }
            }
        }
        return null
    }

    private fun extractDate(text: String): LocalDate? {
        for (pattern in datePatterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val dateString = matcher.group()

                // Try various Australian date formats
                val formats = listOf(
                    "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy",
                    "dd/MM/yy", "dd-MM-yy",
                    "d/M/yyyy", "d-M-yyyy",
                    "dd MMM yyyy", "d MMM yyyy"
                )

                for (format in formats) {
                    try {
                        val formatter = DateTimeFormatter.ofPattern(format)
                        return LocalDate.parse(dateString, formatter)
                    } catch (e: DateTimeParseException) {
                        // Try next format
                    }
                }
            }
        }
        return null
    }
}
```

---

## Camera Integration

### ReceiptCaptureScreen.kt (Jetpack Compose)

```kotlin
package com.locumtracker.ui.receipt

import android.Manifest
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.locumtracker.ocr.OCREngine
import com.locumtracker.ocr.ReceiptData
import com.locumtracker.ocr.ReceiptDataExtractor
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.util.concurrent.Executors

/**
 * ViewModel for receipt capture
 */
class ReceiptCaptureViewModel(
    private val ocrEngine: OCREngine
) : ViewModel() {

    private val _uiState = MutableStateFlow<ReceiptCaptureState>(ReceiptCaptureState.Ready)
    val uiState: StateFlow<ReceiptCaptureState> = _uiState

    private val _extractedData = MutableStateFlow<ReceiptData?>(null)
    val extractedData: StateFlow<ReceiptData?> = _extractedData

    init {
        viewModelScope.launch {
            try {
                ocrEngine.initialize()
            } catch (e: Exception) {
                _uiState.value = ReceiptCaptureState.Error("Failed to initialize OCR: ${e.message}")
            }
        }
    }

    fun processImage(bitmap: Bitmap) {
        viewModelScope.launch {
            _uiState.value = ReceiptCaptureState.Processing

            try {
                val results = ocrEngine.recognizeText(bitmap)
                val receiptData = ReceiptDataExtractor.extract(results)
                _extractedData.value = receiptData
                _uiState.value = ReceiptCaptureState.Success(receiptData)
            } catch (e: Exception) {
                _uiState.value = ReceiptCaptureState.Error("OCR failed: ${e.message}")
            }
        }
    }

    fun reset() {
        _uiState.value = ReceiptCaptureState.Ready
        _extractedData.value = null
    }

    override fun onCleared() {
        super.onCleared()
        ocrEngine.release()
    }
}

sealed class ReceiptCaptureState {
    object Ready : ReceiptCaptureState()
    object Processing : ReceiptCaptureState()
    data class Success(val data: ReceiptData) : ReceiptCaptureState()
    data class Error(val message: String) : ReceiptCaptureState()
}

@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun ReceiptCaptureScreen(
    viewModel: ReceiptCaptureViewModel,
    onReceiptCaptured: (ReceiptData) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val cameraPermissionState = rememberPermissionState(Manifest.permission.CAMERA)
    val uiState by viewModel.uiState.collectAsState()

    var imageCapture by remember { mutableStateOf<ImageCapture?>(null) }
    val cameraExecutor = remember { Executors.newSingleThreadExecutor() }

    LaunchedEffect(uiState) {
        if (uiState is ReceiptCaptureState.Success) {
            onReceiptCaptured((uiState as ReceiptCaptureState.Success).data)
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            cameraExecutor.shutdown()
        }
    }

    if (!cameraPermissionState.status.isGranted) {
        // Request permission
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("Camera permission is required to capture receipts")
            Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = { cameraPermissionState.launchPermissionRequest() }) {
                Text("Grant Permission")
            }
        }
        return
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // Camera Preview
        AndroidView(
            factory = { ctx ->
                val previewView = PreviewView(ctx)
                val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)

                cameraProviderFuture.addListener({
                    val cameraProvider = cameraProviderFuture.get()

                    val preview = Preview.Builder().build().also {
                        it.setSurfaceProvider(previewView.surfaceProvider)
                    }

                    imageCapture = ImageCapture.Builder()
                        .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                        .build()

                    val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                    try {
                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            cameraSelector,
                            preview,
                            imageCapture
                        )
                    } catch (e: Exception) {
                        // Handle error
                    }
                }, ContextCompat.getMainExecutor(ctx))

                previewView
            },
            modifier = Modifier.fillMaxSize()
        )

        // UI Overlay
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Top bar with close button
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = Color.White
                    )
                }
            }

            // Bottom capture button
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                when (uiState) {
                    is ReceiptCaptureState.Processing -> {
                        CircularProgressIndicator(
                            modifier = Modifier.size(70.dp),
                            color = Color.White
                        )
                    }
                    is ReceiptCaptureState.Error -> {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = (uiState as ReceiptCaptureState.Error).message,
                                color = Color.Red
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Button(onClick = { viewModel.reset() }) {
                                Text("Try Again")
                            }
                        }
                    }
                    else -> {
                        // Capture button
                        Button(
                            onClick = {
                                imageCapture?.takePicture(
                                    cameraExecutor,
                                    object : ImageCapture.OnImageCapturedCallback() {
                                        override fun onCaptureSuccess(image: ImageProxy) {
                                            val bitmap = imageProxyToBitmap(image)
                                            image.close()
                                            viewModel.processImage(bitmap)
                                        }

                                        override fun onError(exception: ImageCaptureException) {
                                            // Handle error
                                        }
                                    }
                                )
                            },
                            modifier = Modifier.size(70.dp),
                            shape = CircleShape,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color.White
                            )
                        ) {}
                    }
                }
            }
        }
    }
}

/**
 * Convert ImageProxy to Bitmap with correct rotation
 */
private fun imageProxyToBitmap(imageProxy: ImageProxy): Bitmap {
    val buffer = imageProxy.planes[0].buffer
    val bytes = ByteArray(buffer.remaining())
    buffer.get(bytes)

    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)

    // Rotate if needed
    val rotationDegrees = imageProxy.imageInfo.rotationDegrees
    return if (rotationDegrees != 0) {
        val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
        Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    } else {
        bitmap
    }
}
```

---

## Performance Optimization

### 1. Model Quantization

Reduce model size by ~4x with INT8 quantization:

```python
# quantize_models.py
import onnx
from onnxruntime.quantization import quantize_dynamic, QuantType

# Quantize detection model
quantize_dynamic(
    "pp_ocrv4_det.onnx",
    "pp_ocrv4_det_int8.onnx",
    weight_type=QuantType.QUInt8
)

# Quantize recognition model
quantize_dynamic(
    "pp_ocrv4_rec.onnx",
    "pp_ocrv4_rec_int8.onnx",
    weight_type=QuantType.QUInt8
)
```

### 2. NNAPI Acceleration

Enable hardware acceleration on supported devices:

```kotlin
val sessionOptions = OrtSession.SessionOptions().apply {
    // Try NNAPI first (GPU/DSP/NPU acceleration)
    try {
        addNnapi()
    } catch (e: OrtException) {
        // Fall back to CPU with optimization
        setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
        setIntraOpNumThreads(4)
    }
}
```

### 3. Lazy Loading with Singleton

```kotlin
object OCREngineManager {
    private var engine: OCREngine? = null
    private val lock = Any()

    suspend fun getEngine(context: Context): OCREngine {
        return engine ?: synchronized(lock) {
            engine ?: OCREngine(context.applicationContext).also {
                engine = it
                // Initialize in background
                kotlinx.coroutines.runBlocking {
                    it.initialize()
                }
            }
        }
    }

    fun release() {
        synchronized(lock) {
            engine?.release()
            engine = null
        }
    }
}
```

### 4. Image Preprocessing with RenderScript (deprecated) / Vulkan Compute

For high-performance preprocessing, consider using GPU compute:

```kotlin
// Use Android's Bitmap operations which are hardware-accelerated on modern devices
// Or implement custom Vulkan compute shaders for very high performance
```

### 5. Memory Management

```kotlin
// Always recycle bitmaps when done
fun processWithMemoryManagement(originalBitmap: Bitmap): ReceiptData {
    var processedBitmap: Bitmap? = null
    try {
        processedBitmap = preprocessBitmap(originalBitmap)
        return ocrEngine.recognizeText(processedBitmap).let {
            ReceiptDataExtractor.extract(it)
        }
    } finally {
        processedBitmap?.recycle()
    }
}
```

---

## Testing Strategy

### Unit Tests

```kotlin
// ReceiptDataExtractorTest.kt
package com.locumtracker.ocr

import org.junit.Assert.*
import org.junit.Test
import java.math.BigDecimal
import java.time.LocalDate

class ReceiptDataExtractorTest {

    @Test
    fun `extract total from Woolworths receipt`() {
        val ocrResults = listOf(
            OCRResult("WOOLWORTHS", RectF(), 0.95f),
            OCRResult("Milk 2L  \$3.50", RectF(), 0.9f),
            OCRResult("Bread    \$4.00", RectF(), 0.9f),
            OCRResult("TOTAL    \$7.50", RectF(), 0.95f),
            OCRResult("GST      \$0.68", RectF(), 0.9f)
        )

        val result = ReceiptDataExtractor.extract(ocrResults)

        assertEquals("Woolworths", result.merchant)
        assertEquals(BigDecimal("7.50"), result.totalAmount)
        assertEquals(BigDecimal("0.68"), result.gstAmount)
    }

    @Test
    fun `extract Australian date format`() {
        val ocrResults = listOf(
            OCRResult("Date: 15/01/2026", RectF(), 0.9f)
        )

        val result = ReceiptDataExtractor.extract(ocrResults)

        assertEquals(LocalDate.of(2026, 1, 15), result.date)
    }

    @Test
    fun `extract EFTPOS total`() {
        val ocrResults = listOf(
            OCRResult("EFTPOS \$45.99", RectF(), 0.9f)
        )

        val result = ReceiptDataExtractor.extract(ocrResults)

        assertEquals(BigDecimal("45.99"), result.totalAmount)
    }

    @Test
    fun `handle missing fields gracefully`() {
        val ocrResults = listOf(
            OCRResult("Random text", RectF(), 0.9f)
        )

        val result = ReceiptDataExtractor.extract(ocrResults)

        assertNull(result.totalAmount)
        assertNull(result.date)
        assertNotNull(result.rawText)
    }
}
```

### Instrumented Tests

```kotlin
// OCREngineInstrumentedTest.kt
package com.locumtracker.ocr

import android.content.Context
import android.graphics.BitmapFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class OCREngineInstrumentedTest {

    private lateinit var context: Context
    private lateinit var ocrEngine: OCREngine

    @Before
    fun setup() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        ocrEngine = OCREngine(context)
        runBlocking {
            ocrEngine.initialize()
        }
    }

    @After
    fun teardown() {
        ocrEngine.release()
    }

    @Test
    fun recognizeWoolworthsReceipt() = runBlocking {
        val bitmap = context.assets.open("test_receipts/woolworths_sample.jpg").use {
            BitmapFactory.decodeStream(it)
        }

        val results = ocrEngine.recognizeText(bitmap)

        assertTrue(results.isNotEmpty())
        val fullText = results.joinToString(" ") { it.text }
        assertTrue(
            fullText.contains("WOOLWORTHS", ignoreCase = true) ||
            fullText.contains("Woolworths", ignoreCase = true)
        )

        bitmap.recycle()
    }

    @Test
    fun recognizeAmountFromReceipt() = runBlocking {
        val bitmap = context.assets.open("test_receipts/simple_receipt.jpg").use {
            BitmapFactory.decodeStream(it)
        }

        val results = ocrEngine.recognizeText(bitmap)
        val data = ReceiptDataExtractor.extract(results)

        assertNotNull(data.totalAmount)

        bitmap.recycle()
    }

    @Test
    fun performanceTest() = runBlocking {
        val bitmap = context.assets.open("test_receipts/standard_receipt.jpg").use {
            BitmapFactory.decodeStream(it)
        }

        val startTime = System.currentTimeMillis()
        ocrEngine.recognizeText(bitmap)
        val elapsed = System.currentTimeMillis() - startTime

        // Should complete in under 3 seconds on most devices
        assertTrue("OCR took ${elapsed}ms, expected < 3000ms", elapsed < 3000)

        bitmap.recycle()
    }
}
```

---

## Alternative: Paddle-Lite

For smaller binary size or if ONNX Runtime doesn't work well, use Paddle-Lite directly.

### Gradle Setup

```kotlin
dependencies {
    // Paddle-Lite
    implementation("com.baidu.paddle:paddle-lite:2.12.0")
}
```

### Model Conversion

Convert ONNX to Paddle-Lite `.nb` format:

```bash
# Install paddle-lite tool
pip install paddlelite

# Convert to Paddle-Lite format
paddle_lite_opt \
    --model_file=inference.pdmodel \
    --param_file=inference.pdiparams \
    --optimize_out=pp_ocrv4_det \
    --optimize_out_type=naive_buffer \
    --valid_targets=arm
```

### Usage

```kotlin
import com.baidu.paddle.lite.MobileConfig
import com.baidu.paddle.lite.PaddlePredictor

class PaddleLiteOCREngine(context: Context) {
    private var detPredictor: PaddlePredictor? = null
    private var recPredictor: PaddlePredictor? = null

    fun initialize() {
        val detConfig = MobileConfig().apply {
            setModelFromBuffer(loadModelFromAssets("pp_ocrv4_det.nb"))
            setThreads(4)
            setPowerMode(MobileConfig.PowerMode.LITE_POWER_HIGH)
        }
        detPredictor = PaddlePredictor.createPaddlePredictor(detConfig)

        val recConfig = MobileConfig().apply {
            setModelFromBuffer(loadModelFromAssets("pp_ocrv4_rec.nb"))
            setThreads(4)
        }
        recPredictor = PaddlePredictor.createPaddlePredictor(recConfig)
    }

    // ... rest of implementation similar to ONNX version
}
```

---

## File Structure

```
app/
├── src/
│   ├── main/
│   │   ├── assets/
│   │   │   └── ocr_models/
│   │   │       ├── pp_ocrv4_det.onnx
│   │   │       ├── pp_ocrv4_rec.onnx
│   │   │       └── ppocr_keys.txt
│   │   ├── java/com/locumtracker/
│   │   │   ├── ocr/
│   │   │   │   ├── OCREngine.kt
│   │   │   │   ├── OCRResult.kt
│   │   │   │   ├── ReceiptData.kt
│   │   │   │   └── ReceiptDataExtractor.kt
│   │   │   └── ui/receipt/
│   │   │       ├── ReceiptCaptureScreen.kt
│   │   │       └── ReceiptCaptureViewModel.kt
│   │   ├── res/
│   │   └── AndroidManifest.xml
│   ├── test/
│   │   └── java/com/locumtracker/ocr/
│   │       └── ReceiptDataExtractorTest.kt
│   └── androidTest/
│       ├── assets/test_receipts/
│       │   ├── woolworths_sample.jpg
│       │   ├── coles_sample.jpg
│       │   └── bp_sample.jpg
│       └── java/com/locumtracker/ocr/
│           └── OCREngineInstrumentedTest.kt
├── build.gradle.kts
└── proguard-rules.pro
```

### ProGuard Rules

```proguard
# proguard-rules.pro

# ONNX Runtime
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }

# Keep model loading
-keep class * extends ai.onnxruntime.OrtSession { *; }
```

---

## Summary

| Aspect | Details |
|--------|---------|
| **OCR Engine** | PaddleOCR PP-OCRv4 via ONNX Runtime |
| **Model Size** | ~10 MB (bundled in APK assets) |
| **Runtime Size** | ~5-8 MB (ONNX Runtime Mobile) |
| **Min SDK** | API 24 (Android 7.0) |
| **Acceleration** | NNAPI on supported devices |
| **Offline** | Fully offline capable |
| **Camera** | CameraX with Jetpack Compose |

### Comparison: ONNX Runtime vs Paddle-Lite

| Aspect | ONNX Runtime | Paddle-Lite |
|--------|--------------|-------------|
| Binary Size | ~5-8 MB | ~3-5 MB |
| Documentation | Excellent | Good (mostly Chinese) |
| Swift Support | Yes | No |
| iOS Support | Yes | Limited |
| NNAPI | Yes | Yes |
| Maintenance | Microsoft | Baidu |

**Recommendation**: Use ONNX Runtime for cross-platform consistency with iOS/macOS implementation.
