package com.hherb.locumtracker.data.database.dao

import androidx.room.*
import com.hherb.locumtracker.data.database.entity.LocumProfileEntity
import com.hherb.locumtracker.data.database.entity.QuarterlyQuotaEntity
import kotlinx.coroutines.flow.Flow

/** Room data-access object for [LocumProfileEntity] and [QuarterlyQuotaEntity] rows. */
@Dao
interface ProfileDao {
    // Profile queries
    /** Observes the single stored profile, emitting `null` if none exists. */
    @Query("SELECT * FROM locum_profile LIMIT 1")
    fun getProfile(): Flow<LocumProfileEntity?>

    /** Returns the single stored profile, or `null` if none exists. */
    @Query("SELECT * FROM locum_profile LIMIT 1")
    suspend fun getProfileOnce(): LocumProfileEntity?

    /** Inserts [profile], replacing any existing row with the same primary key. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertProfile(profile: LocumProfileEntity)

    /** Updates the stored row matching [profile]. */
    @Update
    suspend fun updateProfile(profile: LocumProfileEntity)

    /** Deletes all rows from the profile table. */
    @Query("DELETE FROM locum_profile")
    suspend fun deleteProfile()

    // Quarterly Quota queries
    /** Observes all quarterly quotas, most recent quarter first. */
    @Query("SELECT * FROM quarterly_quotas ORDER BY quarterStartDate DESC")
    fun getAllQuotas(): Flow<List<QuarterlyQuotaEntity>>

    /** Observes the quotas for [practitionerId], most recent quarter first. */
    @Query("SELECT * FROM quarterly_quotas WHERE practitionerId = :practitionerId ORDER BY quarterStartDate DESC")
    fun getQuotasForPractitioner(practitionerId: String): Flow<List<QuarterlyQuotaEntity>>

    /** Returns the quota with the given [id], or `null` if none exists. */
    @Query("SELECT * FROM quarterly_quotas WHERE id = :id")
    suspend fun getQuotaById(id: String): QuarterlyQuotaEntity?

    /** Observes the quota with the given [id], emitting `null` if absent. */
    @Query("SELECT * FROM quarterly_quotas WHERE id = :id")
    fun getQuotaByIdFlow(id: String): Flow<QuarterlyQuotaEntity?>

    /**
     * Returns the most recent quota for [practitionerId] whose quarter starts on
     * or before [date] (i.e. the quota in effect at that date), or `null` if none.
     */
    @Query("""
        SELECT * FROM quarterly_quotas 
        WHERE practitionerId = :practitionerId 
        AND quarterStartDate <= :date 
        ORDER BY quarterStartDate DESC 
        LIMIT 1
    """)
    suspend fun getCurrentQuota(practitionerId: String, date: Long): QuarterlyQuotaEntity?

    /** Inserts [quota], replacing any existing row with the same primary key. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertQuota(quota: QuarterlyQuotaEntity)

    /** Updates the stored row matching [quota]. */
    @Update
    suspend fun updateQuota(quota: QuarterlyQuotaEntity)

    /** Deletes the row matching [quota]. */
    @Delete
    suspend fun deleteQuota(quota: QuarterlyQuotaEntity)

    /** Deletes the quota with the given [id]. */
    @Query("DELETE FROM quarterly_quotas WHERE id = :id")
    suspend fun deleteQuotaById(id: String)
}
