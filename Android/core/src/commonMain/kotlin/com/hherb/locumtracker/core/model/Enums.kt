package com.hherb.locumtracker.core.model

import kotlinx.serialization.Serializable

/**
 * How an assignment is paid.
 *
 * @property value Stable serialized identifier persisted with the data.
 */
@Serializable
enum class RateStructure(val value: String) {
    /** Paid a fixed amount per day. */
    DAILY_RATE("daily_rate"),

    /** Paid per hour worked. */
    HOURLY_RATE("hourly_rate");

    companion object {
        /**
         * Resolves a [RateStructure] from its serialized [value].
         *
         * @param value Serialized identifier to look up.
         * @return The matching entry, or [DAILY_RATE] when none matches.
         */
        fun fromValue(value: String): RateStructure =
            entries.find { it.value == value } ?: DAILY_RATE
    }
}

/**
 * Lifecycle status of an assignment.
 *
 * @property value Stable serialized identifier persisted with the data.
 */
@Serializable
enum class AssignmentStatus(val value: String) {
    /** Scheduled but not yet started. */
    PLANNED("planned"),

    /** Currently in progress. */
    ACTIVE("active"),

    /** Finished. */
    COMPLETED("completed"),

    /** Called off before completion. */
    CANCELLED("cancelled");

    /** Human-readable label for the status. */
    val description: String
        get() = when (this) {
            PLANNED -> "Planned"
            ACTIVE -> "Active"
            COMPLETED -> "Completed"
            CANCELLED -> "Cancelled"
        }

    companion object {
        /**
         * Resolves an [AssignmentStatus] from its serialized [value].
         *
         * @param value Serialized identifier to look up.
         * @return The matching entry, or [PLANNED] when none matches.
         */
        fun fromValue(value: String): AssignmentStatus =
            entries.find { it.value == value } ?: PLANNED
    }
}

/**
 * The type of a worked session, affecting which rate applies.
 *
 * @property value Stable serialized identifier persisted with the data.
 */
@Serializable
enum class SessionType(val value: String) {
    /** A standard worked session. */
    REGULAR("regular"),

    /** Time spent on call. */
    ON_CALL("on_call"),

    /** A call-out (being called in while on call). */
    CALL_OUT("call_out");

    /** Human-readable label for the session type. */
    val description: String
        get() = when (this) {
            REGULAR -> "Regular"
            ON_CALL -> "On-Call"
            CALL_OUT -> "Call-Out"
        }

    companion object {
        /**
         * Resolves a [SessionType] from its serialized [value].
         *
         * @param value Serialized identifier to look up.
         * @return The matching entry, or [REGULAR] when none matches.
         */
        fun fromValue(value: String): SessionType =
            entries.find { it.value == value } ?: REGULAR
    }
}

/**
 * Categories used to classify business expenses for tax purposes.
 *
 * @property value Stable serialized identifier persisted with the data.
 */
@Serializable
enum class ExpenseCategory(val value: String) {
    /** Travel expenses. */
    TRAVEL("travel"),

    /** Accommodation expenses. */
    ACCOMMODATION("accommodation"),

    /** Meal expenses. */
    MEALS("meals"),

    /** Medical supply expenses. */
    SUPPLIES("supplies"),

    /** Professional development expenses. */
    PROFESSIONAL("professional"),

    /** Insurance expenses. */
    INSURANCE("insurance"),

    /** Training expenses. */
    TRAINING("training"),

    /** Uncategorised expenses. */
    OTHER("other");

    /** Human-readable label for the category. */
    val description: String
        get() = when (this) {
            TRAVEL -> "Travel"
            ACCOMMODATION -> "Accommodation"
            MEALS -> "Meals"
            SUPPLIES -> "Medical Supplies"
            PROFESSIONAL -> "Professional Development"
            INSURANCE -> "Insurance"
            TRAINING -> "Training"
            OTHER -> "Other"
        }

    /** `true` for every category except [OTHER], which is treated as non-deductible. */
    val isTaxDeductible: Boolean
        get() = this != OTHER

    companion object {
        /**
         * Resolves an [ExpenseCategory] from its serialized [value].
         *
         * @param value Serialized identifier to look up.
         * @return The matching entry, or [OTHER] when none matches.
         */
        fun fromValue(value: String): ExpenseCategory =
            entries.find { it.value == value } ?: OTHER
    }
}

/**
 * Severity level describing how a practitioner is tracking against their quarterly quota.
 *
 * @property value Stable serialized identifier persisted with the data.
 */
@Serializable
enum class QuotaWarningLevel(val value: String) {
    /** The quota has been met. */
    SUCCESS("success"),

    /** Progress is on track to meet the quota. */
    ON_TRACK("on_track"),

    /** Progress is behind and the quota is at risk. */
    AT_RISK("at_risk"),

    /** Progress is critically behind. */
    CRITICAL("critical");

    /** Human-readable label for the warning level. */
    val description: String
        get() = when (this) {
            SUCCESS -> "Quota Met"
            ON_TRACK -> "On Track"
            AT_RISK -> "At Risk"
            CRITICAL -> "Critical"
        }

    companion object {
        /**
         * Resolves a [QuotaWarningLevel] from its serialized [value].
         *
         * @param value Serialized identifier to look up.
         * @return The matching entry, or [ON_TRACK] when none matches.
         */
        fun fromValue(value: String): QuotaWarningLevel =
            entries.find { it.value == value } ?: ON_TRACK
    }
}
