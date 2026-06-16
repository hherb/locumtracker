package com.hherb.locumtracker.data.repository

import com.hherb.locumtracker.data.database.dao.ReceiptDao
import com.hherb.locumtracker.data.database.entity.AttachmentEntity
import com.hherb.locumtracker.data.database.entity.ReceiptEntity
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository providing access to receipts and their attachments.
 *
 * Wraps [ReceiptDao] to expose receipt and attachment persistence operations,
 * ensuring attachments are cleaned up when their parent receipt is deleted.
 */
@Singleton
class ReceiptRepository @Inject constructor(
    private val receiptDao: ReceiptDao
) {
    // Receipt operations
    /** Returns a stream of all receipts. */
    fun getAllReceipts(): Flow<List<ReceiptEntity>> = receiptDao.getAllReceipts()

    /**
     * Returns a stream of receipts linked to the given assignment.
     *
     * @param assignmentId Identifier of the assignment to filter by.
     */
    fun getReceiptsForAssignment(assignmentId: String): Flow<List<ReceiptEntity>> = receiptDao.getReceiptsForAssignment(assignmentId)

    /**
     * Fetches a single receipt by its identifier.
     *
     * @param id Identifier of the receipt.
     * @return The matching receipt, or null if none exists.
     */
    suspend fun getReceiptById(id: String): ReceiptEntity? = receiptDao.getReceiptById(id)

    /**
     * Returns a stream emitting the receipt with the given identifier as it changes.
     *
     * @param id Identifier of the receipt.
     */
    fun getReceiptByIdFlow(id: String): Flow<ReceiptEntity?> = receiptDao.getReceiptByIdFlow(id)

    /**
     * Returns a stream of receipts in the given category.
     *
     * @param category Receipt category to filter by.
     */
    fun getReceiptsByCategory(category: String): Flow<List<ReceiptEntity>> = receiptDao.getReceiptsByCategory(category)

    /** Returns a stream of the total amount across all receipts (null if there are none). */
    fun getTotalExpenses(): Flow<Double?> = receiptDao.getTotalExpenses()

    /**
     * Returns a stream of the total amount of receipts dated on or after the given time.
     *
     * @param startDate Inclusive lower-bound date as epoch milliseconds.
     */
    fun getTotalExpensesSince(startDate: Long): Flow<Double?> = receiptDao.getTotalExpensesSince(startDate)

    /** Inserts a receipt. */
    suspend fun insertReceipt(receipt: ReceiptEntity) = receiptDao.insertReceipt(receipt)

    /** Updates an existing receipt. */
    suspend fun updateReceipt(receipt: ReceiptEntity) = receiptDao.updateReceipt(receipt)

    /**
     * Deletes a receipt along with its attachments, removing the attachments first
     * so no orphans remain.
     *
     * @param receipt The receipt to delete.
     */
    suspend fun deleteReceipt(receipt: ReceiptEntity) {
        // Delete associated attachments first
        receiptDao.deleteAttachmentsForReceipt(receipt.id)
        receiptDao.deleteReceipt(receipt)
    }

    /**
     * Deletes a receipt and its attachments by identifier, removing the attachments first
     * so no orphans remain.
     *
     * @param id Identifier of the receipt to delete.
     */
    suspend fun deleteReceiptById(id: String) {
        receiptDao.deleteAttachmentsForReceipt(id)
        receiptDao.deleteReceiptById(id)
    }

    // Attachment operations
    /** Returns a stream of all attachments. */
    fun getAllAttachments(): Flow<List<AttachmentEntity>> = receiptDao.getAllAttachments()

    /**
     * Returns a stream of attachments belonging to the given receipt.
     *
     * @param receiptId Identifier of the receipt.
     */
    fun getAttachmentsForReceipt(receiptId: String): Flow<List<AttachmentEntity>> = receiptDao.getAttachmentsForReceipt(receiptId)

    /**
     * Returns a stream of attachments belonging to receipts of the given assignment.
     *
     * @param assignmentId Identifier of the assignment.
     */
    fun getAttachmentsForAssignment(assignmentId: String): Flow<List<AttachmentEntity>> = receiptDao.getAttachmentsForAssignment(assignmentId)

    /**
     * Fetches a single attachment by its identifier.
     *
     * @param id Identifier of the attachment.
     * @return The matching attachment, or null if none exists.
     */
    suspend fun getAttachmentById(id: String): AttachmentEntity? = receiptDao.getAttachmentById(id)

    /** Inserts an attachment. */
    suspend fun insertAttachment(attachment: AttachmentEntity) = receiptDao.insertAttachment(attachment)

    /** Updates an existing attachment. */
    suspend fun updateAttachment(attachment: AttachmentEntity) = receiptDao.updateAttachment(attachment)

    /** Deletes an attachment. */
    suspend fun deleteAttachment(attachment: AttachmentEntity) = receiptDao.deleteAttachment(attachment)

    /** Deletes an attachment by its identifier. */
    suspend fun deleteAttachmentById(id: String) = receiptDao.deleteAttachmentById(id)

    /** Deletes all attachments belonging to the given receipt. */
    suspend fun deleteAttachmentsForReceipt(receiptId: String) = receiptDao.deleteAttachmentsForReceipt(receiptId)
}
