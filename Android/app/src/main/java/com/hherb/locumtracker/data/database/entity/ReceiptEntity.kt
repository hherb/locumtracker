package com.hherb.locumtracker.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/** Number of bytes in one kibibyte / mebibyte step used for size formatting. */
private const val BYTES_PER_UNIT = 1024L

/**
 * Room persistence entity for an expense [com.hherb.locumtracker.core.model.Receipt],
 * optionally linked to a daily record and/or an assignment.
 */
@Entity(tableName = "receipts")
data class ReceiptEntity(
    @PrimaryKey val id: String,
    val dailyRecordId: String?,
    val assignmentId: String?,
    val amount: Double,
    val category: String,
    val date: Long,
    val receiptDescription: String,
    val createdAt: Long,
    val updatedAt: Long
)

/**
 * Room persistence entity for a binary file attachment (e.g. a receipt image or
 * PDF) linked to a receipt and/or an assignment. Equality is identity-by-[id].
 */
@Entity(tableName = "attachments")
data class AttachmentEntity(
    @PrimaryKey val id: String,
    val receiptId: String?,
    val assignmentId: String?,
    val filename: String,
    val fileType: String,
    val fileSize: Long,
    val fileData: ByteArray?,
    val notes: String?,
    val createdAt: Long,
    val updatedAt: Long
) {
    /**
     * Human-readable file size, e.g. `"512 B"`, `"4 KB"` or `"2 MB"`.
     */
    val fileSizeFormatted: String
        get() = when {
            fileSize < BYTES_PER_UNIT -> "$fileSize B"
            fileSize < BYTES_PER_UNIT * BYTES_PER_UNIT -> "${fileSize / BYTES_PER_UNIT} KB"
            else -> "${fileSize / (BYTES_PER_UNIT * BYTES_PER_UNIT)} MB"
        }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is AttachmentEntity) return false
        return id == other.id
    }

    override fun hashCode(): Int = id.hashCode()
}
