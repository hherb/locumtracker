package com.hherb.locumtracker.core.service

import com.hherb.locumtracker.core.model.*

/**
 * Pure service for WIP Doctor Stream rural subsidy logic: eligibility, annual payment
 * lookup, MMM descriptions, and FPS session validity helpers.
 */
object RuralSubsidyService {
    private const val SECONDS_PER_HOUR = 3600.0

    /** Fraction of the VR annual payment paid to non-VR (non-training-pathway) participants. */
    private const val NON_VR_PAYMENT_FACTOR = 0.8

    /** Length, in characters, of the leading "YYYY-MM-DD" date portion of an ISO timestamp. */
    private const val ISO_DATE_LENGTH = 10

    /** Inclusive MMM classification range eligible for rural subsidies (MMM3-MMM7). */
    val SUBSIDY_ELIGIBLE_MMM_RANGE = 3..7

    /** Year-1 VR annual WIP payment by MMM classification, in AUD. */
    val vrAnnualPayments = mapOf(
        3 to 4500.0,
        4 to 7500.0,
        5 to 12000.0,
        6 to 25000.0,
        7 to 47000.0
    )

    /** Non-VR annual WIP payments, derived as [NON_VR_PAYMENT_FACTOR] of the VR amounts. */
    val nonVrAnnualPayments = vrAnnualPayments.mapValues { it.value * NON_VR_PAYMENT_FACTOR }

    /**
     * Checks rural-subsidy eligibility for an MMM classification.
     *
     * @param mmmClassification The MMM classification to check.
     * @return `true` when it falls within [SUBSIDY_ELIGIBLE_MMM_RANGE].
     */
    fun isSubsidyEligible(mmmClassification: Int): Boolean {
        return mmmClassification in SUBSIDY_ELIGIBLE_MMM_RANGE
    }

    /**
     * Looks up the annual WIP payment for an MMM classification.
     *
     * @param mmmClassification The MMM classification.
     * @param isVr `true` for VR (training-pathway) rates, `false` for non-VR rates.
     * @return The annual payment, or `0.0` when the classification is not eligible.
     */
    fun getAnnualPayment(mmmClassification: Int, isVr: Boolean): Double {
        val payments = if (isVr) vrAnnualPayments else nonVrAnnualPayments
        return payments[mmmClassification] ?: 0.0
    }

    /**
     * Returns a human-readable description for an MMM classification.
     *
     * @param mmmClassification The MMM classification (1-7).
     * @return The description, or "Unknown" if out of range.
     */
    fun getMmmDescription(mmmClassification: Int): String = when (mmmClassification) {
        1 -> "Major City"
        2 -> "Regional City"
        3 -> "Large Rural Town"
        4 -> "Medium Rural Town"
        5 -> "Small Rural Town"
        6 -> "Remote Community"
        7 -> "Very Remote Community"
        else -> "Unknown"
    }

    /**
     * Checks whether a session meets the minimum continuous duration to count toward the quota.
     *
     * @param session The session to validate.
     * @return `true` when its duration is at least [QuarterlyQuota.MINIMUM_SESSION_DURATION_HOURS].
     */
    fun isValidSession(session: Session): Boolean {
        val durationHours = session.durationHours
        return durationHours >= QuarterlyQuota.MINIMUM_SESSION_DURATION_HOURS
    }

    /**
     * Counts how many sessions fall on each calendar day.
     *
     * @param sessions The sessions to group.
     * @return A map from "YYYY-MM-DD" day key to the number of sessions on that day.
     */
    fun getSessionsPerDay(sessions: List<Session>): Map<String, Int> {
        return sessions.groupBy { session ->
            session.startTime.toString().substring(0, ISO_DATE_LENGTH)
        }.mapValues { it.value.size }
    }

    /**
     * Checks whether another session may still be counted for a given day.
     *
     * @param sessions Existing sessions.
     * @param date Day key in "YYYY-MM-DD" form.
     * @return `true` when fewer than [QuarterlyQuota.MAXIMUM_SESSIONS_PER_DAY] sessions
     *   are already recorded for that day.
     */
    fun canAddMoreSessionsForDay(
        sessions: List<Session>,
        date: String
    ): Boolean {
        val sessionsForDay = sessions.filter {
            it.startTime.toString().substring(0, ISO_DATE_LENGTH) == date
        }
        return sessionsForDay.size < QuarterlyQuota.MAXIMUM_SESSIONS_PER_DAY
    }
}
