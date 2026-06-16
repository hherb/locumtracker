package com.hherb.locumtracker.core.model

import com.hherb.locumtracker.core.util.randomUuidString
import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable

/** Number of bytes in one kilobyte, used when formatting file sizes. */
private const val BYTES_PER_KB = 1024

/**
 * A recorded business expense, optionally linked to a daily record or assignment.
 *
 * @property id Unique identifier for the receipt.
 * @property dailyRecordId Optional identifier of the linked [DailyRecord].
 * @property assignmentId Optional identifier of the linked [Assignment].
 * @property amount Monetary amount of the expense.
 * @property category Expense category used for tax categorisation.
 * @property date Date the expense was incurred.
 * @property receiptDescription Free-text description of the expense.
 * @property createdAt Timestamp when the record was created.
 * @property updatedAt Timestamp when the record was last updated.
 */
@Serializable
data class Receipt(
    val id: String = randomUuidString(),
    val dailyRecordId: String? = null,
    val assignmentId: String? = null,
    val amount: Double = 0.0,
    val category: ExpenseCategory = ExpenseCategory.OTHER,
    val date: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val receiptDescription: String = "",
    val createdAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val updatedAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis())
)

/**
 * A file attachment (e.g. a scanned receipt or PDF) belonging to a receipt or assignment.
 *
 * Equality and hashing are based solely on [id].
 *
 * @property id Unique identifier for the attachment.
 * @property receiptId Optional identifier of the linked [Receipt].
 * @property assignmentId Optional identifier of the linked [Assignment].
 * @property filename Original file name.
 * @property fileType MIME type of the file (e.g. "image/jpeg", "application/pdf").
 * @property fileSize File size in bytes.
 * @property fileData Optional raw file contents.
 * @property notes Optional free-text notes.
 * @property createdAt Timestamp when the record was created.
 * @property updatedAt Timestamp when the record was last updated.
 */
@Serializable
data class Attachment(
    val id: String = randomUuidString(),
    val receiptId: String? = null,
    val assignmentId: String? = null,
    val filename: String,
    val fileType: String,
    val fileSize: Long = 0,
    val fileData: ByteArray? = null,
    val notes: String? = null,
    val createdAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val updatedAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis())
) {
    /** [fileSize] rendered in human-readable units (B, KB, or MB). */
    val fileSizeFormatted: String
        get() = when {
            fileSize < BYTES_PER_KB -> "$fileSize B"
            fileSize < BYTES_PER_KB * BYTES_PER_KB -> "${fileSize / BYTES_PER_KB} KB"
            else -> "${fileSize / (BYTES_PER_KB * BYTES_PER_KB)} MB"
        }

    /** `true` when the [fileType] is a supported image MIME type. */
    val isImage: Boolean
        get() = fileType in listOf("image/jpeg", "image/png", "image/heic")

    /** `true` when the [fileType] is a PDF. */
    val isPDF: Boolean
        get() = fileType == "application/pdf"

    /**
     * Compares attachments by [id] only.
     *
     * @param other The object to compare against.
     * @return `true` if [other] is an [Attachment] with the same [id].
     */
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Attachment) return false
        return id == other.id
    }

    /**
     * @return The hash code derived from [id].
     */
    override fun hashCode(): Int = id.hashCode()
}
