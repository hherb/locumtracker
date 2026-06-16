package com.hherb.locumtracker.ui.screens.receipts

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.AttachmentEntity
import com.hherb.locumtracker.data.database.entity.ReceiptEntity
import com.hherb.locumtracker.data.ocr.ReceiptData
import com.hherb.locumtracker.data.ocr.ReceiptOCRService
import com.hherb.locumtracker.data.repository.ReceiptRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/**
 * ViewModel backing the add-receipt screen. Persists new receipts (with an optional image
 * attachment) and exposes ML Kit OCR helpers for scanning and auto-categorising receipts.
 */
@HiltViewModel
class AddReceiptViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val receiptRepository: ReceiptRepository,
    private val ocrService: ReceiptOCRService
) : ViewModel() {

    /** True while a save operation is in progress; used to disable the save button. */
    val isSaving = MutableStateFlow(false)

    /**
     * Creates and stores a new receipt, attaching the image at [imageUri] if provided.
     *
     * @param amount receipt total in dollars.
     * @param category expense category key.
     * @param description free-text description.
     * @param date receipt date as epoch milliseconds.
     * @param imageUri optional content URI of a captured/selected receipt image.
     */
    fun addReceipt(
        amount: Double,
        category: String,
        description: String,
        date: Long,
        imageUri: String?
    ) {
        viewModelScope.launch {
            isSaving.value = true

            try {
                // Create receipt
                val receipt = ReceiptEntity(
                    id = UUID.randomUUID().toString(),
                    dailyRecordId = null,
                    assignmentId = null,
                    amount = amount,
                    category = category,
                    date = date,
                    receiptDescription = description,
                    createdAt = System.currentTimeMillis(),
                    updatedAt = System.currentTimeMillis()
                )

                receiptRepository.insertReceipt(receipt)

                // If image URI provided, create attachment
                if (imageUri != null) {
                    try {
                        val uri = Uri.parse(imageUri)
                        val inputStream = context.contentResolver.openInputStream(uri)
                        val bytes = inputStream?.readBytes()
                        inputStream?.close()

                        if (bytes != null) {
                            val attachment = AttachmentEntity(
                                id = UUID.randomUUID().toString(),
                                receiptId = receipt.id,
                                assignmentId = null,
                                filename = "receipt_${System.currentTimeMillis()}.jpg",
                                fileType = "image/jpeg",
                                fileSize = bytes.size.toLong(),
                                fileData = bytes,
                                notes = null,
                                createdAt = System.currentTimeMillis(),
                                updatedAt = System.currentTimeMillis()
                            )

                            receiptRepository.insertAttachment(attachment)
                        }
                    } catch (e: Exception) {
                        // Handle image processing error
                    }
                }

                isSaving.value = false
            } catch (e: Exception) {
                isSaving.value = false
            }
        }
    }

    /**
     * Runs OCR on the image at [imageUri] and reports the extracted [ReceiptData], or null on failure.
     *
     * @param imageUri content URI of the receipt image to scan.
     * @param onResult callback receiving the extracted data, or null if extraction failed.
     */
    fun scanReceipt(imageUri: Uri, onResult: (ReceiptData?) -> Unit) {
        viewModelScope.launch {
            try {
                val receiptData = ocrService.extractReceiptData(imageUri)
                onResult(receiptData)
            } catch (e: Exception) {
                onResult(null)
            }
        }
    }

    /** Returns a best-guess expense category key for the given OCR-detected [merchant] name. */
    fun categorizeReceipt(merchant: String?): String {
        return ocrService.categorizeReceipt(merchant)
    }
}
