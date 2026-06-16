package com.hherb.locumtracker.data.ocr

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

/**
 * Structured data extracted from a receipt image by OCR parsing.
 *
 * @property merchant The detected merchant/business name, or null if not found.
 * @property total The detected total amount in dollars, or null if not found.
 * @property gst The detected GST (tax) amount in dollars, or null if not found.
 * @property date The detected transaction date as the raw matched string, or null if not found.
 * @property rawText The full raw text recognised from the image.
 */
data class ReceiptData(
    val merchant: String?,
    val total: Double?,
    val gst: Double?,
    val date: String?,
    val rawText: String
)

/**
 * Service that performs on-device OCR on receipt images using ML Kit text recognition
 * and parses the recognised text into structured [ReceiptData].
 *
 * Uses the Latin text recognizer by default and falls back to the Chinese recognizer
 * when Latin recognition fails.
 */
@Singleton
class ReceiptOCRService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    private val chineseRecognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())

    /**
     * Recognises text from the image at the given URI and parses it into receipt data.
     *
     * @param imageUri The URI of the receipt image to process.
     * @return The parsed [ReceiptData], or null if recognition fails or yields no text.
     */
    suspend fun extractReceiptData(imageUri: Uri): ReceiptData? {
        return try {
            val image = InputImage.fromFilePath(context, imageUri)
            val text = recognizeText(image)
            if (text != null) {
                parseReceiptText(text)
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Recognises text from the given bitmap and parses it into receipt data.
     *
     * @param bitmap The receipt image bitmap to process.
     * @return The parsed [ReceiptData], or null if recognition fails or yields no text.
     */
    suspend fun extractReceiptData(bitmap: Bitmap): ReceiptData? {
        return try {
            val image = InputImage.fromBitmap(bitmap, BITMAP_ROTATION_DEGREES)
            val text = recognizeText(image)
            if (text != null) {
                parseReceiptText(text)
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Recognises text from the given image, falling back to the Chinese recognizer
     * if the Latin recognizer fails.
     *
     * @param image The ML Kit input image to recognise text from.
     * @return The recognised text, or null if both recognizers fail.
     */
    private suspend fun recognizeText(image: InputImage): String? {
        return suspendCancellableCoroutine { continuation ->
            recognizer.process(image)
                .addOnSuccessListener { visionText ->
                    continuation.resume(visionText.text)
                }
                .addOnFailureListener { e ->
                    // Try Chinese recognizer as fallback
                    chineseRecognizer.process(image)
                        .addOnSuccessListener { visionText ->
                            continuation.resume(visionText.text)
                        }
                        .addOnFailureListener {
                            continuation.resume(null)
                        }
                }
        }
    }

    /**
     * Parses recognised receipt text into structured [ReceiptData] by extracting the
     * merchant name, total, GST, and date.
     *
     * @param text The raw recognised text from the receipt image.
     * @return The structured receipt data; fields are null when not detected.
     */
    private fun parseReceiptText(text: String): ReceiptData {
        val lines = text.lines().map { it.trim() }.filter { it.isNotEmpty() }

        // Extract merchant (usually first non-empty line)
        val merchant = lines.firstOrNull { line ->
            !line.contains("$") && !line.contains("TOTAL") &&
            line.length > MIN_MERCHANT_LENGTH && !line.all { it.isDigit() || it == '.' }
        }

        // Extract total amount
        val total = extractTotal(text)

        // Extract GST
        val gst = extractGST(text)

        // Extract date
        val date = extractDate(text)

        return ReceiptData(
            merchant = merchant,
            total = total,
            gst = gst,
            date = date,
            rawText = text
        )
    }

    /**
     * Extracts the total amount from the receipt text.
     *
     * Tries labelled patterns (total/amount/sum and dollar amounts) first, then falls back
     * to the largest two-decimal number found in the text.
     *
     * @param text The raw recognised receipt text.
     * @return The extracted total in dollars, or null if none could be determined.
     */
    private fun extractTotal(text: String): Double? {
        val totalPatterns = listOf(
            Regex("""(?i)total\s*[:\$]*\s*\$?\s*(\d+\.?\d*)"""),
            Regex("""(?i)amount\s*[:\$]*\s*\$?\s*(\d+\.?\d*)"""),
            Regex("""(?i)sum\s*[:\$]*\s*\$?\s*(\d+\.?\d*)"""),
            Regex("""\$\s*(\d+\.?\d*)""")
        )

        for (pattern in totalPatterns) {
            val match = pattern.find(text)
            if (match != null) {
                return match.groupValues[1].toDoubleOrNull()
            }
        }

        // Fallback: find largest number
        val numbers = Regex("""\d+\.\d{2}""").findAll(text)
            .mapNotNull { it.value.toDoubleOrNull() }
            .toList()

        return numbers.maxOrNull()
    }

    /**
     * Extracts the GST (tax) amount from the receipt text using labelled GST/tax patterns.
     *
     * @param text The raw recognised receipt text.
     * @return The extracted GST amount in dollars, or null if none could be determined.
     */
    private fun extractGST(text: String): Double? {
        val gstPatterns = listOf(
            Regex("""(?i)gst\s*[:\$]*\s*\$?\s*(\d+\.?\d*)"""),
            Regex("""(?i)tax\s*[:\$]*\s*\$?\s*(\d+\.?\d*)"""),
            Regex("""(?i)gst\s*\(\s*10\s*%\s*\)\s*[:\$]*\s*\$?\s*(\d+\.?\d*)""")
        )

        for (pattern in gstPatterns) {
            val match = pattern.find(text)
            if (match != null) {
                return match.groupValues[1].toDoubleOrNull()
            }
        }

        return null
    }

    /**
     * Extracts a transaction date from the receipt text by matching common date formats
     * (dd/MM/yyyy, dd-MM-yyyy, dd.MM.yyyy, yyyy/MM/dd).
     *
     * @param text The raw recognised receipt text.
     * @return The matched date as its raw string, or null if no date pattern matched.
     */
    private fun extractDate(text: String): String? {
        val datePatterns = listOf(
            Regex("""\d{2}/\d{2}/\d{4}"""),
            Regex("""\d{2}-\d{2}-\d{4}"""),
            Regex("""\d{2}\.\d{2}\.\d{4}"""),
            Regex("""\d{4}/\d{2}/\d{2}""")
        )

        for (pattern in datePatterns) {
            val match = pattern.find(text)
            if (match != null) {
                return match.value
            }
        }

        return null
    }

    /**
     * Categorises a receipt into an expense category based on keywords in the merchant name.
     *
     * Recognised categories are "travel", "accommodation", "meals", "supplies", and
     * "training"; anything unmatched (or a null merchant) is categorised as "other".
     *
     * @param merchant The merchant name to categorise, or null.
     * @return The expense category string.
     */
    fun categorizeReceipt(merchant: String?): String {
        val merchantLower = merchant?.lowercase() ?: return "other"

        return when {
            merchantLower.contains("petrol") || merchantLower.contains("fuel") ||
            merchantLower.contains("bp") || merchantLower.contains("shell") ||
            merchantLower.contains("caltex") -> "travel"

            merchantLower.contains("hotel") || merchantLower.contains("motel") ||
            merchantLower.contains("airbnb") || merchantLower.contains("accommodation") -> "accommodation"

            merchantLower.contains("restaurant") || merchantLower.contains("cafe") ||
            merchantLower.contains("mcdonald") || merchantLower.contains("kfc") ||
            merchantLower.contains("pizza") -> "meals"

            merchantLower.contains("pharmacy") || merchantLower.contains("chemist") ||
            merchantLower.contains("medical") || merchantLower.contains("hospital") -> "supplies"

            merchantLower.contains("training") || merchantLower.contains("education") ||
            merchantLower.contains("course") -> "training"

            else -> "other"
        }
    }

    private companion object {
        /** Rotation (in degrees) applied to bitmaps passed to ML Kit; images are assumed upright. */
        private const val BITMAP_ROTATION_DEGREES = 0

        /** Minimum character length for a line to be considered a candidate merchant name. */
        private const val MIN_MERCHANT_LENGTH = 3
    }
}
