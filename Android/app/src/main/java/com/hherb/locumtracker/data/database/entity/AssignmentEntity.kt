package com.hherb.locumtracker.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Room persistence entity for a locum [com.hherb.locumtracker.core.model.Assignment].
 *
 * Stores rate structure, date range, status and JSON-encoded collections
 * (templates, additional locations, provider locations) for a single assignment.
 */
@Entity(tableName = "assignments")
data class AssignmentEntity(
    @PrimaryKey val id: String,
    val locationId: String,
    val rateStructure: String,
    val dailyRate: Double?,
    val hourlyRate: Double?,
    val onCallRate: Double?,
    val callOutRate: Double?,
    val startDate: Long,
    val endDate: Long,
    val status: String,
    val createdAt: Long,
    val updatedAt: Long,
    val name: String?,
    val mainProviderNumber: String?,
    val defaultSessionTemplatesJSON: String?,
    val additionalLocationIdsJSON: String?,
    val providerLocationsJSON: String?
)
