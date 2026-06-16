package com.hherb.locumtracker.ui.screens.receipts

import android.content.Context
import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.AttachmentEntity
import com.hherb.locumtracker.data.database.entity.ReceiptEntity
import com.hherb.locumtracker.data.repository.ReceiptRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/**
 * ViewModel backing the edit-receipt screen. Loads the receipt and its attachments by id,
 * persists edits, and supports adding or deleting image attachments.
 */
@HiltViewModel
class EditReceiptViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    @ApplicationContext private val context: Context,
    private val receiptRepository: ReceiptRepository
) : ViewModel() {

    private val receiptId: String = savedStateHandle["receiptId"] ?: ""

    /** The receipt being edited, or null until loaded. */
    private val _receipt = MutableStateFlow<ReceiptEntity?>(null)
    val receipt: StateFlow<ReceiptEntity?> = _receipt.asStateFlow()

    /** Image attachments associated with the receipt. */
    private val _attachments = MutableStateFlow<List<AttachmentEntity>>(emptyList())
    val attachments: StateFlow<List<AttachmentEntity>> = _attachments.asStateFlow()

    /** True while a save operation is in progress; used to disable the save button. */
    val isSaving = MutableStateFlow(false)

    init {
        loadReceipt()
        loadAttachments()
    }

    private fun loadReceipt() {
        viewModelScope.launch {
            receiptRepository.getReceiptByIdFlow(receiptId).collect { receipt ->
                _receipt.value = receipt
            }
        }
    }

    private fun loadAttachments() {
        viewModelScope.launch {
            receiptRepository.getAttachmentsForReceipt(receiptId).collect { attachments ->
                _attachments.value = attachments
            }
        }
    }

    /**
     * Persists edits to the loaded receipt and optionally attaches a new image.
     *
     * @param amount updated receipt total in dollars.
     * @param category updated expense category key.
     * @param description updated free-text description.
     * @param date updated receipt date as epoch milliseconds.
     * @param newImageUri optional content URI of a newly added receipt image.
     */
    fun updateReceipt(
        amount: Double,
        category: String,
        description: String,
        date: Long,
        newImageUri: String?
    ) {
        viewModelScope.launch {
            isSaving.value = true

            try {
                val existing = _receipt.value
                if (existing != null) {
                    receiptRepository.updateReceipt(
                        existing.copy(
                            amount = amount,
                            category = category,
                            receiptDescription = description,
                            date = date,
                            updatedAt = System.currentTimeMillis()
                        )
                    )
                }

                // Add new image if provided
                if (newImageUri != null) {
                    try {
                        val uri = Uri.parse(newImageUri)
                        val inputStream = context.contentResolver.openInputStream(uri)
                        val bytes = inputStream?.readBytes()
                        inputStream?.close()

                        if (bytes != null) {
                            val attachment = AttachmentEntity(
                                id = UUID.randomUUID().toString(),
                                receiptId = receiptId,
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

    /** Deletes the attachment identified by [attachmentId]. */
    fun deleteAttachment(attachmentId: String) {
        viewModelScope.launch {
            receiptRepository.deleteAttachmentById(attachmentId)
        }
    }
}
