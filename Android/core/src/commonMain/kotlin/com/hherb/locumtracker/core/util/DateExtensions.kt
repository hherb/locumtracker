package com.hherb.locumtracker.core.util

import kotlinx.datetime.*

/**
 * Time-zone-aware [Instant] and [Double] extensions for day/quarter boundaries,
 * predicates, and human-readable formatting. All operations use the system default time zone.
 */
object DateExtensions {
    private val timeZone = TimeZone.currentSystemDefault()

    /** Number of months in a calendar quarter. */
    private const val MONTHS_PER_QUARTER = 3

    /** Number of months from a quarter's first to its last month (inclusive offset). */
    private const val QUARTER_END_MONTH_OFFSET = 2

    /** Number of months in a calendar year, used for end-of-quarter year rollover. */
    private const val MONTHS_PER_YEAR = 12

    /** Number of characters taken from a month name for medium date formatting. */
    private const val MONTH_ABBREVIATION_LENGTH = 3

    /** Number of seconds in one hour, used for formatting durations. */
    private const val SECONDS_PER_HOUR = 3600

    /** Number of seconds in one minute, used for formatting durations. */
    private const val SECONDS_PER_MINUTE = 60

    /** @return The instant at the start of this instant's calendar day. */
    fun Instant.startOfDay(): Instant {
        val localDate = this.toLocalDateTime(timeZone).date
        return localDate.atStartOfDayIn(timeZone)
    }

    /** @return The instant one second before the start of the next day (i.e. end of this day). */
    fun Instant.endOfDay(): Instant {
        val localDate = this.toLocalDateTime(timeZone).date
        return localDate.plus(1, DateTimeUnit.DAY).atStartOfDayIn(timeZone)
            .minus(1, DateTimeUnit.SECOND)
    }

    /** @return The instant at the start of the first day of this instant's quarter. */
    fun Instant.startOfQuarter(): Instant {
        val localDate = this.toLocalDateTime(timeZone).date
        val quarterMonth = ((localDate.monthNumber - 1) / MONTHS_PER_QUARTER) * MONTHS_PER_QUARTER + 1
        val quarterStart = LocalDate(localDate.year, quarterMonth, 1)
        return quarterStart.atStartOfDayIn(timeZone)
    }

    /** @return The instant at the start of the last day of this instant's quarter. */
    fun Instant.endOfQuarter(): Instant {
        val localDate = this.toLocalDateTime(timeZone).date
        val endMonth = localDate.monthNumber + QUARTER_END_MONTH_OFFSET
        val year = if (endMonth > MONTHS_PER_YEAR) localDate.year + 1 else localDate.year
        val month = if (endMonth > MONTHS_PER_YEAR) endMonth - MONTHS_PER_YEAR else endMonth
        val lastDayOfMonth = LocalDate(year, month, 1).daysInMonth
        val quarterEnd = LocalDate(year, month, lastDayOfMonth)
        return quarterEnd.atStartOfDayIn(timeZone)
    }

    /**
     * @param days Number of days to add (may be negative).
     * @return This instant advanced by [days] calendar days.
     */
    fun Instant.addingDays(days: Int): Instant {
        return this.plus(days, DateTimeUnit.DAY, timeZone)
    }

    /** @return `true` when this instant falls on a Saturday or Sunday. */
    fun Instant.isWeekend(): Boolean {
        val dayOfWeek = this.toLocalDateTime(timeZone).dayOfWeek
        return dayOfWeek == DayOfWeek.SATURDAY || dayOfWeek == DayOfWeek.SUNDAY
    }

    /** @return `true` when this instant falls on the current calendar day. */
    fun Instant.isToday(): Boolean {
        val today = Clock.System.now().toLocalDateTime(timeZone).date
        val thisDate = this.toLocalDateTime(timeZone).date
        return today == thisDate
    }

    /** @return `true` when this instant is strictly before the current time. */
    fun Instant.isInPast(): Boolean {
        return this < Clock.System.now()
    }

    /** @return This instant's date formatted as "DD/MM/YYYY". */
    fun Instant.shortDateString(): String {
        val localDate = this.toLocalDateTime(timeZone).date
        return "%02d/%02d/%04d".format(localDate.dayOfMonth, localDate.monthNumber, localDate.year)
    }

    /** @return This instant's date formatted as "DD Mon YYYY" (abbreviated month name). */
    fun Instant.mediumDateString(): String {
        val localDate = this.toLocalDateTime(timeZone).date
        return "%02d %s %04d".format(
            localDate.dayOfMonth,
            localDate.month.name.take(MONTH_ABBREVIATION_LENGTH),
            localDate.year
        )
    }

    /**
     * Formats a duration given in seconds as a compact "Xh Ym" / "Xh" / "Ym" string.
     *
     * @return The formatted duration string.
     */
    fun Double.toFormattedDuration(): String {
        val totalSeconds = this.toInt()
        val h = totalSeconds / SECONDS_PER_HOUR
        val m = (totalSeconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE
        return when {
            h > 0 && m > 0 -> "${h}h ${m}m"
            h > 0 -> "${h}h"
            else -> "${m}m"
        }
    }

    /**
     * Counts the inclusive number of calendar days between two instants.
     *
     * @param from Start instant.
     * @param to End instant.
     * @return The number of days from [from] to [to], inclusive of both endpoints.
     */
    fun daysInRange(from: Instant, to: Instant): Int {
        val fromLocal = from.toLocalDateTime(timeZone).date
        val toLocal = to.toLocalDateTime(timeZone).date
        return fromLocal.daysUntil(toLocal) + 1
    }

    /** Number of days in this date's month, accounting for leap years. */
    private val LocalDate.daysInMonth: Int
        get() = when (monthNumber) {
            1, 3, 5, 7, 8, 10, 12 -> 31
            4, 6, 9, 11 -> 30
            2 -> if (isLeapYear()) 29 else 28
            else -> 30
        }

    /** @return `true` when this date's year is a Gregorian leap year. */
    private fun LocalDate.isLeapYear(): Boolean {
        return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }
}
