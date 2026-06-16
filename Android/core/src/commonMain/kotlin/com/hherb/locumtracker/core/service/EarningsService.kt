package com.hherb.locumtracker.core.service

import com.hherb.locumtracker.core.model.*

/**
 * Pure calculation service for session, daily, and subsidy earnings, plus effective
 * hourly rates. All functions are side-effect free.
 */
object EarningsService {
    private const val SECONDS_PER_HOUR = 3600.0

    /** Lowest MMM classification (inclusive) eligible for the per-hour subsidy. */
    private const val MIN_RURAL_SUBSIDY_MMM = 3

    /** Highest MMM classification (inclusive) eligible for the per-hour subsidy. */
    private const val MAX_RURAL_SUBSIDY_MMM = 7

    /** Per-hour subsidy rate for MMM3 (Large Rural Town). */
    private const val SUBSIDY_RATE_MMM3 = 100.0

    /** Per-hour subsidy rate for MMM4 (Medium Rural Town). */
    private const val SUBSIDY_RATE_MMM4 = 150.0

    /** Per-hour subsidy rate for MMM5 (Small Rural Town). */
    private const val SUBSIDY_RATE_MMM5 = 200.0

    /** Per-hour subsidy rate for MMM6 (Remote Community). */
    private const val SUBSIDY_RATE_MMM6 = 300.0

    /** Per-hour subsidy rate for MMM7 (Very Remote Community). */
    private const val SUBSIDY_RATE_MMM7 = 400.0

    /**
     * Calculates the earnings for a single session.
     *
     * @param session The session to value.
     * @param assignment The assignment supplying the rate structure and rates.
     * @return The hourly rate times session hours (hourly), or the daily rate (daily);
     *   `0.0` when the relevant rate is `null`.
     */
    fun calculateSessionEarnings(
        session: Session,
        assignment: Assignment
    ): Double {
        return when (assignment.rateStructure) {
            RateStructure.HOURLY_RATE -> {
                val hourlyRate = assignment.hourlyRate ?: 0.0
                session.durationHours * hourlyRate
            }
            RateStructure.DAILY_RATE -> {
                assignment.dailyRate ?: 0.0
            }
        }
    }

    /**
     * Calculates the total earnings for a day's sessions.
     *
     * @param sessions The sessions worked that day.
     * @param assignment The assignment supplying the rate structure and rates.
     * @return `0.0` when [sessions] is empty; otherwise the daily rate (daily structure)
     *   or the sum of per-session earnings (hourly structure).
     */
    fun calculateDailyEarnings(
        sessions: List<Session>,
        assignment: Assignment
    ): Double {
        if (sessions.isEmpty()) return 0.0
        return when (assignment.rateStructure) {
            RateStructure.DAILY_RATE -> assignment.dailyRate ?: 0.0
            RateStructure.HOURLY_RATE -> {
                sessions.sumOf { calculateSessionEarnings(it, assignment) }
            }
        }
    }

    /**
     * Calculates the rural subsidy amount for a session based on its MMM classification.
     *
     * @param session The session whose effective subsidy hours are used.
     * @param mmmClassification MMM classification driving the per-hour rate.
     * @return The effective subsidy hours times the per-hour rate for MMM3-MMM7;
     *   `0.0` when the classification is outside the eligible range or the session is not eligible.
     */
    fun calculateSubsidyAmount(
        session: Session,
        mmmClassification: Int
    ): Double {
        if (mmmClassification !in MIN_RURAL_SUBSIDY_MMM..MAX_RURAL_SUBSIDY_MMM) return 0.0
        if (!session.isSubsidyEligible) return 0.0

        val hours = session.effectiveSubsidyHours
        return when (mmmClassification) {
            3 -> hours * SUBSIDY_RATE_MMM3
            4 -> hours * SUBSIDY_RATE_MMM4
            5 -> hours * SUBSIDY_RATE_MMM5
            6 -> hours * SUBSIDY_RATE_MMM6
            7 -> hours * SUBSIDY_RATE_MMM7
            else -> 0.0
        }
    }

    /**
     * Calculates an effective hourly rate from totals.
     *
     * @param totalEarnings Total earnings over the period.
     * @param totalHours Total hours worked over the period.
     * @return Earnings divided by hours, or `0.0` when [totalHours] is not positive.
     */
    fun calculateEffectiveHourlyRate(totalEarnings: Double, totalHours: Double): Double {
        return if (totalHours > 0) totalEarnings / totalHours else 0.0
    }
}
