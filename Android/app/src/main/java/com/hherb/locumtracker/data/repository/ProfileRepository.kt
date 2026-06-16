package com.hherb.locumtracker.data.repository

import com.hherb.locumtracker.data.database.dao.ProfileDao
import com.hherb.locumtracker.data.database.entity.LocumProfileEntity
import com.hherb.locumtracker.data.database.entity.QuarterlyQuotaEntity
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository providing access to the locum profile and quarterly WIP quotas.
 *
 * Wraps [ProfileDao] to expose persistence operations for the single locum profile and
 * for the quarterly quota records used to track WIP Doctor Stream eligibility.
 */
@Singleton
class ProfileRepository @Inject constructor(
    private val profileDao: ProfileDao
) {
    // Profile operations
    /** Returns a stream of the locum profile (null if none has been created yet). */
    fun getProfile(): Flow<LocumProfileEntity?> = profileDao.getProfile()

    /** Fetches the locum profile once, or null if none has been created yet. */
    suspend fun getProfileOnce(): LocumProfileEntity? = profileDao.getProfileOnce()

    /** Inserts the locum profile. */
    suspend fun insertProfile(profile: LocumProfileEntity) = profileDao.insertProfile(profile)

    /** Updates the existing locum profile. */
    suspend fun updateProfile(profile: LocumProfileEntity) = profileDao.updateProfile(profile)

    /** Deletes the locum profile. */
    suspend fun deleteProfile() = profileDao.deleteProfile()

    // Quarterly Quota operations
    /** Returns a stream of all quarterly quotas. */
    fun getAllQuotas(): Flow<List<QuarterlyQuotaEntity>> = profileDao.getAllQuotas()

    /**
     * Returns a stream of quarterly quotas for the given practitioner.
     *
     * @param practitionerId Identifier of the practitioner.
     */
    fun getQuotasForPractitioner(practitionerId: String): Flow<List<QuarterlyQuotaEntity>> = profileDao.getQuotasForPractitioner(practitionerId)

    /**
     * Fetches a single quarterly quota by its identifier.
     *
     * @param id Identifier of the quota.
     * @return The matching quota, or null if none exists.
     */
    suspend fun getQuotaById(id: String): QuarterlyQuotaEntity? = profileDao.getQuotaById(id)

    /**
     * Returns a stream emitting the quarterly quota with the given identifier as it changes.
     *
     * @param id Identifier of the quota.
     */
    fun getQuotaByIdFlow(id: String): Flow<QuarterlyQuotaEntity?> = profileDao.getQuotaByIdFlow(id)

    /**
     * Fetches the quarterly quota covering the given date for a practitioner.
     *
     * @param practitionerId Identifier of the practitioner.
     * @param date Date as epoch milliseconds.
     * @return The quota covering the date, or null if none exists.
     */
    suspend fun getCurrentQuota(practitionerId: String, date: Long): QuarterlyQuotaEntity? = profileDao.getCurrentQuota(practitionerId, date)

    /** Inserts a quarterly quota. */
    suspend fun insertQuota(quota: QuarterlyQuotaEntity) = profileDao.insertQuota(quota)

    /** Updates an existing quarterly quota. */
    suspend fun updateQuota(quota: QuarterlyQuotaEntity) = profileDao.updateQuota(quota)

    /** Deletes a quarterly quota. */
    suspend fun deleteQuota(quota: QuarterlyQuotaEntity) = profileDao.deleteQuota(quota)

    /** Deletes a quarterly quota by its identifier. */
    suspend fun deleteQuotaById(id: String) = profileDao.deleteQuotaById(id)
}
