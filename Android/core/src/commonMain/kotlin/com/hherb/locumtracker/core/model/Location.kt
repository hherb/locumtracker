package com.hherb.locumtracker.core.model

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import com.hherb.locumtracker.core.util.randomUuidString

/** Lowest MMM classification (inclusive) that is eligible for rural subsidies. */
private const val MIN_RURAL_SUBSIDY_MMM = 3

/** Highest MMM classification (inclusive) that is eligible for rural subsidies. */
private const val MAX_RURAL_SUBSIDY_MMM = 7

/** Number of minutes in one hour, used to convert wall-clock times to durations. */
private const val MINUTES_PER_HOUR = 60

/** Number of minutes in one hour as a [Double], used for fractional-hour conversion. */
private const val MINUTES_PER_HOUR_DOUBLE = 60.0

/**
 * A practice location where locum work is performed.
 *
 * The [mmmClassification] (Modified Monash Model, 1-7) drives rural-subsidy
 * eligibility: classifications 3-7 are rural/remote and eligible.
 *
 * @property id Unique identifier for the location.
 * @property name Display name of the location.
 * @property address Postal address of the location.
 * @property mmmClassification Modified Monash Model classification (1-7).
 * @property latitude Optional geographic latitude.
 * @property longitude Optional geographic longitude.
 * @property effectiveFrom Date from which this location record is effective.
 * @property effectiveTo Optional date after which this record is no longer effective.
 * @property createdAt Timestamp when the record was created.
 * @property updatedAt Timestamp when the record was last updated.
 * @property providerNumber Optional Medicare provider number for this location.
 * @property phoneNumber Optional contact phone number.
 * @property notes Optional free-text notes.
 * @property defaultDailyRate Optional default daily rate for assignments at this location.
 * @property defaultHourlyRate Optional default hourly rate for assignments at this location.
 * @property defaultOnCallRate Optional default on-call rate for assignments at this location.
 * @property defaultCallOutRate Optional default call-out rate for assignments at this location.
 * @property defaultSessionTemplatesJSON Serialized default session templates as JSON.
 */
@Serializable
data class Location(
    val id: String = randomUuidString(),
    val name: String = "",
    val address: String = "",
    val mmmClassification: Int = 1,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val effectiveFrom: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val effectiveTo: Instant? = null,
    val createdAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val updatedAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val providerNumber: String? = null,
    val phoneNumber: String? = null,
    val notes: String? = null,
    val defaultDailyRate: Double? = null,
    val defaultHourlyRate: Double? = null,
    val defaultOnCallRate: Double? = null,
    val defaultCallOutRate: Double? = null,
    val defaultSessionTemplatesJSON: String? = null
) {
    /** `true` when the [mmmClassification] falls within the rural-subsidy-eligible range (MMM3-MMM7). */
    val isRuralSubsidyEligible: Boolean
        get() = mmmClassification in MIN_RURAL_SUBSIDY_MMM..MAX_RURAL_SUBSIDY_MMM

    /** `true` when at least one default rate has been configured for this location. */
    val hasDefaultRates: Boolean
        get() = defaultDailyRate != null || defaultHourlyRate != null ||
                defaultOnCallRate != null || defaultCallOutRate != null

    /** `true` when default session templates have been configured for this location. */
    val hasDefaultSessionTemplates: Boolean
        get() = !defaultSessionTemplatesJSON.isNullOrEmpty()

    /** Human-readable description of the [mmmClassification], or "Unknown" if out of range. */
    val mmmClassificationDescription: String
        get() = when (mmmClassification) {
            1 -> "MMM1 - Major City"
            2 -> "MMM2 - Regional City"
            3 -> "MMM3 - Large Rural Town"
            4 -> "MMM4 - Medium Rural Town"
            5 -> "MMM5 - Small Rural Town"
            6 -> "MMM6 - Remote Community"
            7 -> "MMM7 - Very Remote Community"
            else -> "Unknown"
        }
}

/**
 * A reusable template describing a session's start and end time of day.
 *
 * @property id Unique identifier for the template.
 * @property startHour Hour of day the session starts (0-23).
 * @property startMinute Minute of the hour the session starts (0-59).
 * @property endHour Hour of day the session ends (0-23).
 * @property endMinute Minute of the hour the session ends (0-59).
 * @property label Optional human-readable label for the template.
 */
@Serializable
data class DefaultSessionTemplate(
    val id: String = randomUuidString(),
    val startHour: Int,
    val startMinute: Int,
    val endHour: Int,
    val endMinute: Int,
    val label: String? = null
) {
    /** Duration of the template in fractional hours, or `0.0` if the end is not after the start. */
    val durationHours: Double
        get() {
            val startMinutes = startHour * MINUTES_PER_HOUR + startMinute
            val endMinutes = endHour * MINUTES_PER_HOUR + endMinute
            val durationMinutes = endMinutes - startMinutes
            return if (durationMinutes > 0) durationMinutes.toDouble() / MINUTES_PER_HOUR_DOUBLE else 0.0
        }

    /** The start and end times formatted as "HH:mm - HH:mm". */
    val timeRangeFormatted: String
        get() {
            val startStr = "%02d:%02d".format(startHour, startMinute)
            val endStr = "%02d:%02d".format(endHour, endMinute)
            return "$startStr - $endStr"
        }
}
