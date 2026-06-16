package com.hherb.locumtracker.ui.screens.receipts

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.ReceiptEntity
import com.hherb.locumtracker.data.repository.ReceiptRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Time in milliseconds to keep the [totalExpenses] flow active after the last subscriber unsubscribes. */
private const val FLOW_SUBSCRIPTION_TIMEOUT_MS = 5000L

/**
 * ViewModel for the receipts list screen. Exposes the full list of receipts and the running total
 * of expenses, and supports deleting individual receipts.
 */
@HiltViewModel
class ReceiptsViewModel @Inject constructor(
    private val receiptRepository: ReceiptRepository
) : ViewModel() {

    /** All stored receipts, ordered by the repository, emitted as UI state. */
    private val _receipts = MutableStateFlow<List<ReceiptEntity>>(emptyList())
    val receipts: StateFlow<List<ReceiptEntity>> = _receipts.asStateFlow()

    /** Sum of all receipt amounts; defaults to 0.0 when there are no receipts. */
    val totalExpenses: StateFlow<Double> = receiptRepository.getTotalExpenses()
        .map { it ?: 0.0 }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(FLOW_SUBSCRIPTION_TIMEOUT_MS), 0.0)

    init {
        loadReceipts()
    }

    private fun loadReceipts() {
        viewModelScope.launch {
            receiptRepository.getAllReceipts().collect { receipts ->
                _receipts.value = receipts
            }
        }
    }

    /** Deletes the given [receipt] from storage. */
    fun deleteReceipt(receipt: ReceiptEntity) {
        viewModelScope.launch {
            receiptRepository.deleteReceipt(receipt)
        }
    }
}
