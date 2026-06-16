package com.hherb.locumtracker.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Lowest Modified Monash Model (MMM) classification that qualifies a location
 * for rural subsidy payments (MMM3 through MMM7 are eligible).
 */
private const val MIN_SUBSIDY_ELIGIBLE_MMM = 3

/**
 * Highest valid Modified Monash Model (MMM) classification.
 */
private const val MAX_MMM = 7

/**
 * Room persistence entity for a work [com.hherb.locumtracker.core.model.Location].
 *
 * Mirrors the core domain model but stores timestamps as epoch-millisecond
 * [Long]s for SQLite compatibility.
 */
@Entity(tableName = "locations")
data class LocationEntity(
    @PrimaryKey val id: String,
    val name: String,
    val address: String,
    val mmmClassification: Int,
    val latitude: Double?,
    val longitude: Double?,
    val effectiveFrom: Long,
    val effectiveTo: Long?,
    val createdAt: Long,
    val updatedAt: Long,
    val providerNumber: String?,
    val phoneNumber: String?,
    val notes: String?,
    val defaultDailyRate: Double?,
    val defaultHourlyRate: Double?,
    val defaultOnCallRate: Double?,
    val defaultCallOutRate: Double?,
    val defaultSessionTemplatesJSON: String?
) {
    /**
     * `true` when this location's MMM classification (MMM3–MMM7) makes it
     * eligible for rural subsidy payments.
     */
    val isRuralSubsidyEligible: Boolean
        get() = mmmClassification in MIN_SUBSIDY_ELIGIBLE_MMM..MAX_MMM

    /**
     * Human-readable label for the location's MMM classification,
     * e.g. `"MMM3 - Large Rural Town"`.
     */
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
