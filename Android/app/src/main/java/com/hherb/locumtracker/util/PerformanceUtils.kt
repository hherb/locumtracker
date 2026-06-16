package com.hherb.locumtracker.util

import java.text.SimpleDateFormat
import java.util.*

/** Number of milliseconds in one second. */
private const val MILLIS_PER_SECOND = 1000L

/** Number of seconds in one minute. */
private const val SECONDS_PER_MINUTE = 60L

/** Number of minutes in one hour. */
private const val MINUTES_PER_HOUR = 60L

/** Number of milliseconds in one minute. */
private const val MILLIS_PER_MINUTE = MILLIS_PER_SECOND * SECONDS_PER_MINUTE

/** Number of milliseconds in one hour. */
private const val MILLIS_PER_HOUR = MILLIS_PER_MINUTE * MINUTES_PER_HOUR

/**
 * Utilities for formatting and parsing dates and times using locale-aware formats.
 */
object DateUtils {
    private val shortDateFormat = SimpleDateFormat("dd/MM/yyyy", Locale.getDefault())
    private val mediumDateFormat = SimpleDateFormat("dd MMM yyyy", Locale.getDefault())
    private val longDateFormat = SimpleDateFormat("dd MMMM yyyy", Locale.getDefault())
    private val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
    private val dateTimeFormat = SimpleDateFormat("dd MMM yyyy HH:mm", Locale.getDefault())

    /**
     * Formats a timestamp as a short date (dd/MM/yyyy).
     *
     * @param timestamp Epoch-millisecond timestamp.
     * @return The formatted date string.
     */
    fun formatShortDate(timestamp: Long): String {
        return shortDateFormat.format(Date(timestamp))
    }

    /**
     * Formats a timestamp as a medium date (dd MMM yyyy).
     *
     * @param timestamp Epoch-millisecond timestamp.
     * @return The formatted date string.
     */
    fun formatMediumDate(timestamp: Long): String {
        return mediumDateFormat.format(Date(timestamp))
    }

    /**
     * Formats a timestamp as a long date (dd MMMM yyyy).
     *
     * @param timestamp Epoch-millisecond timestamp.
     * @return The formatted date string.
     */
    fun formatLongDate(timestamp: Long): String {
        return longDateFormat.format(Date(timestamp))
    }

    /**
     * Formats a timestamp as a time of day (HH:mm).
     *
     * @param timestamp Epoch-millisecond timestamp.
     * @return The formatted time string.
     */
    fun formatTime(timestamp: Long): String {
        return timeFormat.format(Date(timestamp))
    }

    /**
     * Formats a timestamp as a combined date and time (dd MMM yyyy HH:mm).
     *
     * @param timestamp Epoch-millisecond timestamp.
     * @return The formatted date-time string.
     */
    fun formatDateTime(timestamp: Long): String {
        return dateTimeFormat.format(Date(timestamp))
    }

    /**
     * Parses a date string into an epoch-millisecond timestamp.
     *
     * @param dateString The date string to parse.
     * @param format The date format pattern to use; defaults to "dd/MM/yyyy".
     * @return The parsed timestamp in milliseconds, or null if parsing fails.
     */
    fun parseDate(dateString: String, format: String = "dd/MM/yyyy"): Long? {
        return try {
            SimpleDateFormat(format, Locale.getDefault()).parse(dateString)?.time
        } catch (e: Exception) {
            null
        }
    }
}

/**
 * Utilities for formatting and parsing currency values.
 */
object CurrencyUtils {
    /**
     * Formats an amount as a dollar currency string with two decimal places.
     *
     * @param amount The amount to format.
     * @return The formatted currency string, e.g. "$12.50".
     */
    fun formatCurrency(amount: Double): String {
        return "$${String.format("%.2f", amount)}"
    }

    /**
     * Formats an amount as a currency string with a custom symbol and two decimal places.
     *
     * @param amount The amount to format.
     * @param symbol The currency symbol to prefix; defaults to "$".
     * @return The formatted currency string.
     */
    fun formatCurrencyWithSymbol(amount: Double, symbol: String = "$"): String {
        return "$symbol${String.format("%.2f", amount)}"
    }

    /**
     * Parses a currency string into a numeric amount, stripping dollar signs and commas.
     *
     * @param currencyString The currency string to parse.
     * @return The parsed amount, or null if parsing fails.
     */
    fun parseCurrency(currencyString: String): Double? {
        return currencyString
            .replace("$", "")
            .replace(",", "")
            .trim()
            .toDoubleOrNull()
    }
}

/**
 * Utilities for computing and formatting durations between timestamps.
 */
object DurationUtils {
    /**
     * Formats the duration between two timestamps as a compact "Xh Ym" string.
     *
     * @param startTimestamp Start epoch-millisecond timestamp.
     * @param endTimestamp End epoch-millisecond timestamp.
     * @return The formatted duration string.
     */
    fun formatDuration(startTimestamp: Long, endTimestamp: Long): String {
        val durationMs = endTimestamp - startTimestamp
        val hours = durationMs / MILLIS_PER_HOUR
        val minutes = (durationMs % MILLIS_PER_HOUR) / MILLIS_PER_MINUTE

        return when {
            hours > 0 && minutes > 0 -> "${hours}h ${minutes}m"
            hours > 0 -> "${hours}h"
            else -> "${minutes}m"
        }
    }

    /**
     * Formats a fractional number of hours as a compact "Xh Ym" string.
     *
     * @param hours The duration in hours (may include a fractional part).
     * @return The formatted duration string.
     */
    fun formatDurationHours(hours: Double): String {
        val h = hours.toInt()
        val m = ((hours - h) * MINUTES_PER_HOUR).toInt()
        return when {
            h > 0 && m > 0 -> "${h}h ${m}m"
            h > 0 -> "${h}h"
            else -> "${m}m"
        }
    }

    /**
     * Calculates the number of hours between two timestamps.
     *
     * @param startTimestamp Start epoch-millisecond timestamp.
     * @param endTimestamp End epoch-millisecond timestamp.
     * @return The duration in fractional hours.
     */
    fun calculateHours(startTimestamp: Long, endTimestamp: Long): Double {
        return (endTimestamp - startTimestamp).toDouble() / MILLIS_PER_HOUR
    }
}

/**
 * Utilities for common string manipulation tasks.
 */
object StringUtils {
    /** Length of the ellipsis ("...") appended when truncating text. */
    private const val ELLIPSIS_LENGTH = 3

    /**
     * Truncates text to a maximum length, appending an ellipsis if truncation occurs.
     *
     * @param text The text to truncate.
     * @param maxLength The maximum allowed length of the returned string.
     * @return The original text, or a truncated version ending in "...".
     */
    fun truncate(text: String, maxLength: Int): String {
        return if (text.length > maxLength) {
            text.take(maxLength - ELLIPSIS_LENGTH) + "..."
        } else {
            text
        }
    }

    /**
     * Capitalises the first character of the given text.
     *
     * @param text The text to capitalise.
     * @return The text with its first character uppercased.
     */
    fun capitalizeFirst(text: String): String {
        return text.replaceFirstChar { it.uppercase() }
    }

    /**
     * Determines whether the given text is null, empty, or only whitespace.
     *
     * @param text The text to check.
     * @return True if the text is null or blank.
     */
    fun isBlankOrEmpty(text: String?): Boolean {
        return text.isNullOrBlank()
    }
}
