package com.hherb.locumtracker.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Room persistence entity for the locum practitioner's profile, including
 * personal details, business/tax registration and default billing rates.
 */
@Entity(tableName = "locum_profile")
data class LocumProfileEntity(
    @PrimaryKey val id: String,
    val title: String?,
    val firstName: String,
    val lastName: String,
    val email: String?,
    val streetAddress: String?,
    val suburb: String?,
    val state: String?,
    val postcode: String?,
    val businessStructure: String?,
    val abn: String?,
    val isGstRegistered: Boolean,
    val isVocationalRegister: Boolean,
    val providerNumber: String?,
    val specialty: String?,
    val defaultDailyRate: Double?,
    val defaultHourlyRate: Double?,
    val defaultOnCallRate: Double?,
    val defaultCallOutRate: Double?,
    val createdAt: Long,
    val updatedAt: Long
)

/**
 * Room persistence entity tracking a practitioner's counted WIP sessions per
 * MMM classification for a single quarter, used for subsidy quota compliance.
 */
@Entity(tableName = "quarterly_quotas")
data class QuarterlyQuotaEntity(
    @PrimaryKey val id: String,
    val practitionerId: String,
    val quarterStartDate: Long,
    val mmm3Sessions: Int,
    val mmm4Sessions: Int,
    val mmm5Sessions: Int,
    val mmm6Sessions: Int,
    val mmm7Sessions: Int,
    val totalSessions: Int,
    val quotaMet: Boolean,
    val lastUpdated: Long
)
