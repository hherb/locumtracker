package com.hherb.locumtracker.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/** Number of milliseconds in one second. */
private const val MILLIS_PER_SECOND = 1000.0

/** Number of seconds in one minute. */
private const val SECONDS_PER_MINUTE = 60

/** Number of seconds in one hour. */
private const val SECONDS_PER_HOUR = 3600

/**
 * Room persistence entity for a work [com.hherb.locumtracker.core.model.Session].
 *
 * Mirrors the core domain model but stores timestamps as epoch-millisecond
 * [Long]s for SQLite compatibility.
 */
@Entity(tableName = "sessions")
data class SessionEntity(
    @PrimaryKey val id: String,
    val dailyRecordId: String,
    val startTime: Long,
    val endTime: Long,
    val sessionType: String,
    val mmmClassification: Int,
    val travelTime: Double?,
    val subsidyAmount: Double?,
    val notes: String?,
    val locationId: String?,
    val providerLocationId: String?,
    val createdAt: Long,
    val updatedAt: Long
) {
    /** Session length in fractional hours, derived from [startTime] and [endTime]. */
    val durationHours: Double
        get() = (endTime - startTime) / (SECONDS_PER_HOUR * MILLIS_PER_SECOND)

    /**
     * Session length formatted for display, e.g. `"3h 30m"`, `"4h"` or `"45m"`.
     */
    val durationFormatted: String
        get() {
            val totalSeconds = ((endTime - startTime) / MILLIS_PER_SECOND).toInt()
            val hours = totalSeconds / SECONDS_PER_HOUR
            val minutes = (totalSeconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE
            return when {
                hours > 0 && minutes > 0 -> "${hours}h ${minutes}m"
                hours > 0 -> "${hours}h"
                else -> "${minutes}m"
            }
        }
}

/**
 * Room persistence entity for a single day's work record under an assignment,
 * aggregating its sessions, on-call status and total earnings.
 */
@Entity(tableName = "daily_records")
data class DailyRecordEntity(
    @PrimaryKey val id: String,
    val assignmentId: String,
    val date: Long,
    val isOnCall: Boolean,
    val totalEarnings: Double,
    val notes: String?,
    val createdAt: Long,
    val updatedAt: Long
)
