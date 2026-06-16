package com.hherb.locumtracker.ui.screens.receipts

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.AttachmentEntity
import com.hherb.locumtracker.data.database.entity.ReceiptEntity
import com.hherb.locumtracker.data.repository.ReceiptRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel backing the receipt detail screen. Loads the receipt and its attachments by id,
 * tracks the delete-confirmation dialog state, and supports deleting the receipt.
 */
@HiltViewModel
class ReceiptDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val receiptRepository: ReceiptRepository
) : ViewModel() {

    private val receiptId: String = savedStateHandle["receiptId"] ?: ""

    /** The receipt being viewed, or null until loaded. */
    private val _receipt = MutableStateFlow<ReceiptEntity?>(null)
    val receipt: StateFlow<ReceiptEntity?> = _receipt.asStateFlow()

    /** Image attachments associated with the receipt. */
    private val _attachments = MutableStateFlow<List<AttachmentEntity>>(emptyList())
    val attachments: StateFlow<List<AttachmentEntity>> = _attachments.asStateFlow()

    /** Whether the delete-confirmation dialog is currently shown. */
    val showDeleteDialog = MutableStateFlow(false)

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

    /** Deletes the currently loaded receipt from storage. */
    fun deleteReceipt() {
        viewModelScope.launch {
            receiptRepository.deleteReceiptById(receiptId)
        }
    }
}
