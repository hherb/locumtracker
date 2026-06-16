package com.hherb.locumtracker.data.database.dao

import androidx.room.*
import com.hherb.locumtracker.data.database.entity.LocationEntity
import kotlinx.coroutines.flow.Flow

/** Room data-access object for [LocationEntity] rows. */
@Dao
interface LocationDao {
    /** Observes all locations, sorted alphabetically by name. */
    @Query("SELECT * FROM locations ORDER BY name ASC")
    fun getAllLocations(): Flow<List<LocationEntity>>

    /** Observes locations eligible for rural subsidy (MMM3 and above), sorted by name. */
    @Query("SELECT * FROM locations WHERE mmmClassification >= 3 ORDER BY name ASC")
    fun getSubsidyEligibleLocations(): Flow<List<LocationEntity>>

    /** Returns the location with the given [id], or `null` if none exists. */
    @Query("SELECT * FROM locations WHERE id = :id")
    suspend fun getLocationById(id: String): LocationEntity?

    /** Observes the location with the given [id], emitting `null` if absent. */
    @Query("SELECT * FROM locations WHERE id = :id")
    fun getLocationByIdFlow(id: String): Flow<LocationEntity?>

    /** Inserts [location], replacing any existing row with the same primary key. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLocation(location: LocationEntity)

    /** Updates the stored row matching [location]. */
    @Update
    suspend fun updateLocation(location: LocationEntity)

    /** Deletes the row matching [location]. */
    @Delete
    suspend fun deleteLocation(location: LocationEntity)

    /** Deletes the location with the given [id]. */
    @Query("DELETE FROM locations WHERE id = :id")
    suspend fun deleteLocationById(id: String)

    /** Returns the total number of locations. */
    @Query("SELECT COUNT(*) FROM locations")
    suspend fun getLocationCount(): Int
}
