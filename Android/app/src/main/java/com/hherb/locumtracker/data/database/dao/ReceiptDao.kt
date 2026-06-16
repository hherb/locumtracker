package com.hherb.locumtracker.data.database.dao

import androidx.room.*
import com.hherb.locumtracker.data.database.entity.AttachmentEntity
import com.hherb.locumtracker.data.database.entity.ReceiptEntity
import kotlinx.coroutines.flow.Flow

/** Room data-access object for [ReceiptEntity] and [AttachmentEntity] rows. */
@Dao
interface ReceiptDao {
    // Receipt queries
    /** Observes all receipts, newest date first. */
    @Query("SELECT * FROM receipts ORDER BY date DESC")
    fun getAllReceipts(): Flow<List<ReceiptEntity>>

    /** Observes the receipts linked to [assignmentId], newest date first. */
    @Query("SELECT * FROM receipts WHERE assignmentId = :assignmentId ORDER BY date DESC")
    fun getReceiptsForAssignment(assignmentId: String): Flow<List<ReceiptEntity>>

    /** Returns the receipt with the given [id], or `null` if none exists. */
    @Query("SELECT * FROM receipts WHERE id = :id")
    suspend fun getReceiptById(id: String): ReceiptEntity?

    /** Observes the receipt with the given [id], emitting `null` if absent. */
    @Query("SELECT * FROM receipts WHERE id = :id")
    fun getReceiptByIdFlow(id: String): Flow<ReceiptEntity?>

    /** Observes the receipts in [category], newest date first. */
    @Query("SELECT * FROM receipts WHERE category = :category ORDER BY date DESC")
    fun getReceiptsByCategory(category: String): Flow<List<ReceiptEntity>>

    /** Observes the summed amount of all receipts (`null` when there are none). */
    @Query("SELECT SUM(amount) FROM receipts")
    fun getTotalExpenses(): Flow<Double?>

    /** Observes the summed amount of receipts dated on or after [startDate] (`null` if none). */
    @Query("SELECT SUM(amount) FROM receipts WHERE date >= :startDate")
    fun getTotalExpensesSince(startDate: Long): Flow<Double?>

    /** Inserts [receipt], replacing any existing row with the same primary key. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertReceipt(receipt: ReceiptEntity)

    /** Updates the stored row matching [receipt]. */
    @Update
    suspend fun updateReceipt(receipt: ReceiptEntity)

    /** Deletes the row matching [receipt]. */
    @Delete
    suspend fun deleteReceipt(receipt: ReceiptEntity)

    /** Deletes the receipt with the given [id]. */
    @Query("DELETE FROM receipts WHERE id = :id")
    suspend fun deleteReceiptById(id: String)

    // Attachment queries
    /** Observes all attachments, oldest creation time first. */
    @Query("SELECT * FROM attachments ORDER BY createdAt ASC")
    fun getAllAttachments(): Flow<List<AttachmentEntity>>

    /** Observes the attachments linked to [receiptId], oldest creation time first. */
    @Query("SELECT * FROM attachments WHERE receiptId = :receiptId ORDER BY createdAt ASC")
    fun getAttachmentsForReceipt(receiptId: String): Flow<List<AttachmentEntity>>

    /** Observes the attachments linked to [assignmentId], oldest creation time first. */
    @Query("SELECT * FROM attachments WHERE assignmentId = :assignmentId ORDER BY createdAt ASC")
    fun getAttachmentsForAssignment(assignmentId: String): Flow<List<AttachmentEntity>>

    /** Returns the attachment with the given [id], or `null` if none exists. */
    @Query("SELECT * FROM attachments WHERE id = :id")
    suspend fun getAttachmentById(id: String): AttachmentEntity?

    /** Inserts [attachment], replacing any existing row with the same primary key. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAttachment(attachment: AttachmentEntity)

    /** Updates the stored row matching [attachment]. */
    @Update
    suspend fun updateAttachment(attachment: AttachmentEntity)

    /** Deletes the row matching [attachment]. */
    @Delete
    suspend fun deleteAttachment(attachment: AttachmentEntity)

    /** Deletes the attachment with the given [id]. */
    @Query("DELETE FROM attachments WHERE id = :id")
    suspend fun deleteAttachmentById(id: String)

    /** Deletes all attachments linked to [receiptId]. */
    @Query("DELETE FROM attachments WHERE receiptId = :receiptId")
    suspend fun deleteAttachmentsForReceipt(receiptId: String)
}
