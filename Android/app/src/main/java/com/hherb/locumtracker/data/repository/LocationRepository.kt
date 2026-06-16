package com.hherb.locumtracker.data.repository

import com.hherb.locumtracker.data.database.dao.LocationDao
import com.hherb.locumtracker.data.database.entity.LocationEntity
import com.hherb.locumtracker.core.model.DefaultSessionTemplate
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository providing access to locations.
 *
 * Wraps [LocationDao] for location persistence and decodes the per-location default
 * session templates stored as JSON.
 */
@Singleton
class LocationRepository @Inject constructor(
    private val locationDao: LocationDao
) {
    /** Returns a stream of all locations. */
    fun getAllLocations(): Flow<List<LocationEntity>> = locationDao.getAllLocations()

    /** Returns a stream of locations eligible for rural subsidy. */
    fun getSubsidyEligibleLocations(): Flow<List<LocationEntity>> = locationDao.getSubsidyEligibleLocations()

    /**
     * Fetches a single location by its identifier.
     *
     * @param id Identifier of the location.
     * @return The matching location, or null if none exists.
     */
    suspend fun getLocationById(id: String): LocationEntity? = locationDao.getLocationById(id)

    /**
     * Returns a stream emitting the location with the given identifier as it changes.
     *
     * @param id Identifier of the location.
     */
    fun getLocationByIdFlow(id: String): Flow<LocationEntity?> = locationDao.getLocationByIdFlow(id)

    /** Inserts a location. */
    suspend fun insertLocation(location: LocationEntity) = locationDao.insertLocation(location)

    /** Updates an existing location. */
    suspend fun updateLocation(location: LocationEntity) = locationDao.updateLocation(location)

    /** Deletes a location. */
    suspend fun deleteLocation(location: LocationEntity) = locationDao.deleteLocation(location)

    /** Deletes a location by its identifier. */
    suspend fun deleteLocationById(id: String) = locationDao.deleteLocationById(id)

    /** Returns the total number of locations. */
    suspend fun getLocationCount(): Int = locationDao.getLocationCount()

    /**
     * Returns a stream of the default session templates configured for a location,
     * decoded from the location's stored JSON.
     *
     * Emits an empty list when the location has no stored templates or when the stored
     * JSON cannot be parsed.
     *
     * @param locationId Identifier of the location.
     */
    fun getDefaultSessionTemplates(locationId: String): Flow<List<DefaultSessionTemplate>> {
        return locationDao.getLocationByIdFlow(locationId).map { location ->
            if (location?.defaultSessionTemplatesJSON.isNullOrEmpty()) {
                emptyList()
            } else {
                try {
                    Json.decodeFromString<List<DefaultSessionTemplate>>(location!!.defaultSessionTemplatesJSON!!)
                } catch (e: Exception) {
                    emptyList()
                }
            }
        }
    }
}
