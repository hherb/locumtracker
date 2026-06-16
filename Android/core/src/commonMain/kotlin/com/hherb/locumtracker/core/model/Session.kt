package com.hherb.locumtracker.core.model

import com.hherb.locumtracker.core.util.randomUuidString
import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable

/** Number of seconds in one hour, used to convert durations to fractional hours. */
private const val SECONDS_PER_HOUR = 3600.0

/** Minimum travel time, in seconds (1 hour), required before travel counts toward subsidy hours. */
private const val MIN_TRAVEL_TIME_FOR_SUBSIDY = 3600.0

/** Number of milliseconds in one second, used to convert epoch milliseconds to seconds. */
private const val MILLIS_PER_SECOND = 1000

/** Number of milliseconds in one second as a [Double], used for fractional-second conversion. */
private const val MILLIS_PER_SECOND_DOUBLE = 1000.0

/** Number of seconds in one hour as an [Int], used for formatting durations. */
private const val SECONDS_PER_HOUR_INT = 3600

/** Number of seconds in one minute, used for formatting durations. */
private const val SECONDS_PER_MINUTE = 60

/** Lowest MMM classification (inclusive) that is eligible for rural subsidies. */
private const val MIN_RURAL_SUBSIDY_MMM = 3

/** Highest MMM classification (inclusive) that is eligible for rural subsidies. */
private const val MAX_RURAL_SUBSIDY_MMM = 7

/**
 * A single worked session within a [DailyRecord].
 *
 * Duration is derived from [startTime] and [endTime]; subsidy eligibility depends on
 * the [mmmClassification] (MMM3-MMM7 are eligible).
 *
 * @property id Unique identifier for the session.
 * @property dailyRecordId Identifier of the [DailyRecord] this session belongs to.
 * @property startTime When the session started.
 * @property endTime When the session ended.
 * @property sessionType The type of session (regular, on-call, call-out).
 * @property mmmClassification Modified Monash Model classification (1-7) where the session occurred.
 * @property travelTime Optional travel time in seconds associated with the session.
 * @property subsidyAmount Optional pre-computed subsidy amount for the session.
 * @property notes Optional free-text notes.
 * @property locationId Optional identifier of the [Location] for the session.
 * @property providerLocationId Optional identifier of a specific provider location for the session.
 * @property createdAt Timestamp when the record was created.
 * @property updatedAt Timestamp when the record was last updated.
 */
@Serializable
data class Session(
    val id: String = randomUuidString(),
    val dailyRecordId: String,
    val startTime: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val endTime: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val sessionType: SessionType = SessionType.REGULAR,
    val mmmClassification: Int = 1,
    val travelTime: Double? = null,
    val subsidyAmount: Double? = null,
    val notes: String? = null,
    val locationId: String? = null,
    val providerLocationId: String? = null,
    val createdAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val updatedAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis())
) {
    /** Session duration in fractional hours. */
    val durationHours: Double
        get() = (endTime.toEpochMilliseconds() - startTime.toEpochMilliseconds()) / (SECONDS_PER_HOUR * MILLIS_PER_SECOND)

    /** Session duration in fractional seconds. */
    val durationSeconds: Double
        get() = (endTime.toEpochMilliseconds() - startTime.toEpochMilliseconds()) / MILLIS_PER_SECOND_DOUBLE

    /** Session duration formatted as a compact "Xh Ym" / "Xh" / "Ym" string. */
    val durationFormatted: String
        get() {
            val totalSeconds = durationSeconds.toInt()
            val hours = totalSeconds / SECONDS_PER_HOUR_INT
            val minutes = (totalSeconds % SECONDS_PER_HOUR_INT) / SECONDS_PER_MINUTE
            return when {
                hours > 0 && minutes > 0 -> "${hours}h ${minutes}m"
                hours > 0 -> "${hours}h"
                else -> "${minutes}m"
            }
        }

    /**
     * Total hours counted toward subsidies: the session duration plus travel time,
     * but only when travel time exceeds [MIN_TRAVEL_TIME_FOR_SUBSIDY].
     */
    val effectiveSubsidyHours: Double
        get() {
            val baseHours = durationHours
            val travelHours = if (travelTime != null && travelTime > MIN_TRAVEL_TIME_FOR_SUBSIDY) {
                travelTime / SECONDS_PER_HOUR
            } else {
                0.0
            }
            return baseHours + travelHours
        }

    /** `true` when the [mmmClassification] falls within the rural-subsidy-eligible range (MMM3-MMM7). */
    val isSubsidyEligible: Boolean
        get() = mmmClassification in MIN_RURAL_SUBSIDY_MMM..MAX_RURAL_SUBSIDY_MMM

    /** `true` when the session is tied to a specific provider location. */
    val hasSpecificProviderLocation: Boolean
        get() = providerLocationId != null
}

/**
 * Aggregates the sessions, on-call status, and earnings recorded for a single day
 * within an assignment.
 *
 * @property id Unique identifier for the daily record.
 * @property assignmentId Identifier of the [Assignment] this record belongs to.
 * @property date The calendar day this record covers.
 * @property isOnCall Whether the practitioner was on call on this day.
 * @property totalEarnings Total earnings recorded for the day.
 * @property notes Optional free-text notes.
 * @property createdAt Timestamp when the record was created.
 * @property updatedAt Timestamp when the record was last updated.
 */
@Serializable
data class DailyRecord(
    val id: String = randomUuidString(),
    val assignmentId: String,
    val date: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val isOnCall: Boolean = false,
    val totalEarnings: Double = 0.0,
    val notes: String? = null,
    val createdAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val updatedAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis())
)
