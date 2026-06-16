package com.hherb.locumtracker.core.service

import com.hherb.locumtracker.core.model.*
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.toLocalDateTime

/**
 * Pure service for FPS quarter boundaries, valid-session counting, and quota progress.
 * All functions are side-effect free.
 */
object FPSQuarterService {
    private const val SECONDS_PER_HOUR = 3600.0

    /** Minimum continuous duration, in hours, for a session to count toward the quota. */
    private const val MIN_SESSION_DURATION_HOURS = 3.0

    /** Number of months in a calendar quarter. */
    private const val MONTHS_PER_QUARTER = 3

    /** Number of months from a quarter's first to its last month (inclusive offset). */
    private const val QUARTER_END_MONTH_OFFSET = 2

    /** Number of months in a calendar year, used for end-of-quarter year rollover. */
    private const val MONTHS_PER_YEAR = 12

    /** Progress percentage below which the quota is considered critical. */
    private const val CRITICAL_PROGRESS_PERCENT = 50

    /** Progress percentage below which the quota is considered at risk. */
    private const val AT_RISK_PROGRESS_PERCENT = 75

    /**
     * Returns the start instant of the quarter containing [date].
     *
     * @param date Any instant within the target quarter.
     * @return The instant at the start of the quarter's first day, in the system time zone.
     */
    fun getQuarterStartDate(date: Instant): Instant {
        val localDate = date.toLocalDateTime(TimeZone.currentSystemDefault()).date
        val quarterMonth = ((localDate.monthNumber - 1) / MONTHS_PER_QUARTER) * MONTHS_PER_QUARTER + 1
        val quarterStart = LocalDate(localDate.year, quarterMonth, 1)
        return quarterStart.atStartOfDayIn(TimeZone.currentSystemDefault())
    }

    /**
     * Returns the instant at the start of the last day of the quarter that begins at [quarterStartDate].
     *
     * @param quarterStartDate The start instant of a quarter.
     * @return The instant at the start of the quarter's final day, in the system time zone.
     */
    fun getQuarterEndDate(quarterStartDate: Instant): Instant {
        val localDate = quarterStartDate.toLocalDateTime(TimeZone.currentSystemDefault()).date
        val endMonth = localDate.monthNumber + QUARTER_END_MONTH_OFFSET
        val year = if (endMonth > MONTHS_PER_YEAR) localDate.year + 1 else localDate.year
        val month = if (endMonth > MONTHS_PER_YEAR) endMonth - MONTHS_PER_YEAR else endMonth
        val lastDayOfMonth = LocalDate(year, month, 1).daysInMonth
        val quarterEnd = LocalDate(year, month, lastDayOfMonth)
        return quarterEnd.atStartOfDayIn(TimeZone.currentSystemDefault())
    }

    /**
     * Filters the sessions that count toward the FPS quota for a quarter: started within
     * the quarter, at least [MIN_SESSION_DURATION_HOURS] long, and subsidy-eligible.
     *
     * @param sessions Candidate sessions.
     * @param quarterStart Inclusive start of the quarter.
     * @param quarterEnd Exclusive end of the quarter.
     * @return The sessions that satisfy all validity conditions.
     */
    fun countValidSessions(
        sessions: List<Session>,
        quarterStart: Instant,
        quarterEnd: Instant
    ): List<Session> {
        return sessions.filter { session ->
            session.startTime >= quarterStart &&
            session.startTime < quarterEnd &&
            session.durationHours >= MIN_SESSION_DURATION_HOURS &&
            session.isSubsidyEligible
        }
    }

    /**
     * Builds a [QuarterlyQuota] by tallying the supplied valid sessions by MMM classification.
     *
     * @param validSessions Sessions already confirmed valid for the quarter.
     * @param quarterStart Start of the quarter used as the quota's start date.
     * @param quarterEnd Exclusive end of the quarter (not currently used in the tally).
     * @return A populated quota for the quarter.
     */
    fun calculateQuotaProgress(
        validSessions: List<Session>,
        quarterStart: Instant,
        quarterEnd: Instant
    ): QuarterlyQuota {
        val quota = QuarterlyQuota(
            practitionerId = "",
            quarterStartDate = quarterStart
        )

        validSessions.forEach { session ->
            quota.addSession(session.mmmClassification)
        }

        return quota
    }

    /**
     * Derives a warning level from a quota's progress.
     *
     * @param quota The quota to assess.
     * @return [QuotaWarningLevel.SUCCESS] if met, [QuotaWarningLevel.CRITICAL] below
     *   [CRITICAL_PROGRESS_PERCENT], [QuotaWarningLevel.AT_RISK] below
     *   [AT_RISK_PROGRESS_PERCENT], otherwise [QuotaWarningLevel.ON_TRACK].
     */
    fun getWarningLevel(quota: QuarterlyQuota): QuotaWarningLevel {
        if (quota.quotaMet) return QuotaWarningLevel.SUCCESS
        if (quota.progressPercentage < CRITICAL_PROGRESS_PERCENT) return QuotaWarningLevel.CRITICAL
        if (quota.progressPercentage < AT_RISK_PROGRESS_PERCENT) return QuotaWarningLevel.AT_RISK
        return QuotaWarningLevel.ON_TRACK
    }

    /**
     * Checks whether a participant meets the active-quarter eligibility requirements.
     *
     * @param sessionsCount Sessions accumulated.
     * @param requiredSessions Minimum sessions required.
     * @param totalQuarters Active quarters accumulated.
     * @param requiredQuarters Minimum active quarters required.
     * @return `true` when both the session and quarter minimums are satisfied.
     */
    fun isEligibleForQuarter(
        sessionsCount: Int,
        requiredSessions: Int,
        totalQuarters: Int,
        requiredQuarters: Int
    ): Boolean {
        return sessionsCount >= requiredSessions &&
               totalQuarters >= requiredQuarters
    }

    /** Number of days in this date's month, accounting for leap years. */
    private val LocalDate.daysInMonth: Int
        get() = when (monthNumber) {
            1, 3, 5, 7, 8, 10, 12 -> 31
            4, 6, 9, 11 -> 30
            2 -> if (isLeapYear()) 29 else 28
            else -> 30
        }

    /**
     * @return `true` when this date's year is a Gregorian leap year.
     */
    private fun LocalDate.isLeapYear(): Boolean {
        return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }
}
