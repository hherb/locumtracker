package com.hherb.locumtracker.core.model

import com.hherb.locumtracker.core.util.randomUuidString
import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable

/** Approximate number of milliseconds in a 30-day month, used to derive the quarter label. */
private const val MILLIS_PER_MONTH = 30L * 24 * 60 * 60 * 1000

/** Approximate number of milliseconds in a 365-day year, used to derive the quarter label. */
private const val MILLIS_PER_YEAR = 365L * 24 * 60 * 60 * 1000

/** Number of months in one calendar year. */
private const val MONTHS_PER_YEAR = 12

/** Number of months in one calendar quarter. */
private const val MONTHS_PER_QUARTER = 3

/** The Unix epoch year, used as the base year when computing the quarter label. */
private const val EPOCH_YEAR = 1970

/** Multiplier to convert a fraction into a percentage value. */
private const val PERCENT_MULTIPLIER = 100

/**
 * Tracks a practitioner's FPS (Flexible Payment System) session counts for a single
 * quarter, broken down by MMM classification.
 *
 * A quarter's quota is met once [totalSessions] reaches [MINIMUM_SESSIONS]; sessions
 * beyond [MAXIMUM_SESSIONS] do not carry over.
 *
 * @property id Unique identifier for the quota record.
 * @property practitionerId Identifier of the practitioner this quota belongs to.
 * @property quarterStartDate Start date of the quarter this quota covers.
 * @property mmm3Sessions Count of valid MMM3 sessions.
 * @property mmm4Sessions Count of valid MMM4 sessions.
 * @property mmm5Sessions Count of valid MMM5 sessions.
 * @property mmm6Sessions Count of valid MMM6 sessions.
 * @property mmm7Sessions Count of valid MMM7 sessions.
 * @property totalSessions Counted session total, capped at [MAXIMUM_SESSIONS].
 * @property quotaMet Whether the quarterly minimum has been reached.
 * @property lastUpdated Timestamp when the quota was last updated.
 */
@Serializable
data class QuarterlyQuota(
    val id: String = randomUuidString(),
    val practitionerId: String,
    val quarterStartDate: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    var mmm3Sessions: Int = 0,
    var mmm4Sessions: Int = 0,
    var mmm5Sessions: Int = 0,
    var mmm6Sessions: Int = 0,
    var mmm7Sessions: Int = 0,
    var totalSessions: Int = 0,
    var quotaMet: Boolean = false,
    val lastUpdated: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis())
) {
    companion object {
        /** Minimum number of sessions required for a quarter to be "active". */
        const val MINIMUM_SESSIONS = 21

        /** Maximum number of sessions counted per quarter; the excess does not carry over. */
        const val MAXIMUM_SESSIONS = 104

        /** Minimum continuous duration, in hours, for a session to count toward the quota. */
        const val MINIMUM_SESSION_DURATION_HOURS = 3.0

        /** Maximum number of sessions that can be counted on a single day. */
        const val MAXIMUM_SESSIONS_PER_DAY = 2
    }

    /** Sum of all MMM3-MMM7 session counts before the [MAXIMUM_SESSIONS] cap is applied. */
    val rawTotalSessions: Int
        get() = mmm3Sessions + mmm4Sessions + mmm5Sessions + mmm6Sessions + mmm7Sessions

    /** Progress toward [MINIMUM_SESSIONS] expressed as a percentage. */
    val progressPercentage: Double
        get() = totalSessions.toDouble() / MINIMUM_SESSIONS * PERCENT_MULTIPLIER

    /** Number of additional sessions still needed to meet [MINIMUM_SESSIONS] (never negative). */
    val remainingSessions: Int
        get() = maxOf(0, MINIMUM_SESSIONS - totalSessions)

    /** Number of sessions beyond [MAXIMUM_SESSIONS] that will not be counted (never negative). */
    val excessSessions: Int
        get() = maxOf(0, rawTotalSessions - MAXIMUM_SESSIONS)

    /** Human-readable label for the quarter, e.g. "2026 Q2", derived from [quarterStartDate]. */
    val quarterString: String
        get() {
            val month = quarterStartDate.toEpochMilliseconds() / MILLIS_PER_MONTH % MONTHS_PER_YEAR + 1
            val quarter = ((month - 1) / MONTHS_PER_QUARTER + 1)
            val year = EPOCH_YEAR + quarterStartDate.toEpochMilliseconds() / MILLIS_PER_YEAR
            return "$year Q$quarter"
        }

    /**
     * Increments the session count for the given MMM classification and recomputes totals.
     *
     * @param mmmClassification MMM classification (3-7); other values are ignored.
     */
    fun addSession(mmmClassification: Int) {
        when (mmmClassification) {
            3 -> mmm3Sessions++
            4 -> mmm4Sessions++
            5 -> mmm5Sessions++
            6 -> mmm6Sessions++
            7 -> mmm7Sessions++
            else -> return
        }
        recalculateTotals()
    }

    /**
     * Decrements the session count for the given MMM classification (never below zero)
     * and recomputes totals.
     *
     * @param mmmClassification MMM classification (3-7); other values are ignored.
     */
    fun removeSession(mmmClassification: Int) {
        when (mmmClassification) {
            3 -> mmm3Sessions = maxOf(0, mmm3Sessions - 1)
            4 -> mmm4Sessions = maxOf(0, mmm4Sessions - 1)
            5 -> mmm5Sessions = maxOf(0, mmm5Sessions - 1)
            6 -> mmm6Sessions = maxOf(0, mmm6Sessions - 1)
            7 -> mmm7Sessions = maxOf(0, mmm7Sessions - 1)
            else -> return
        }
        recalculateTotals()
    }

    /**
     * Recomputes [totalSessions] (capped at [MAXIMUM_SESSIONS]) and [quotaMet] from the
     * per-classification session counts.
     *
     * Visible within the module (rather than private) so tests can recompute derived
     * totals after seeding session counts directly.
     */
    internal fun recalculateTotals() {
        totalSessions = minOf(rawTotalSessions, MAXIMUM_SESSIONS)
        quotaMet = totalSessions >= MINIMUM_SESSIONS
    }

    /**
     * Returns the recorded session count for a given MMM classification.
     *
     * @param mmm MMM classification (3-7).
     * @return The session count, or `0` if [mmm] is outside the 3-7 range.
     */
    fun sessions(mmm: Int): Int = when (mmm) {
        3 -> mmm3Sessions
        4 -> mmm4Sessions
        5 -> mmm5Sessions
        6 -> mmm6Sessions
        7 -> mmm7Sessions
        else -> 0
    }
}
