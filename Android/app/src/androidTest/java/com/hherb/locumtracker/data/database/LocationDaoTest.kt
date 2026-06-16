package com.hherb.locumtracker.data.database

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hherb.locumtracker.data.database.dao.LocationDao
import com.hherb.locumtracker.data.database.entity.LocationEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LocationDaoTest {

    private lateinit var database: LocumTrackerDatabase
    private lateinit var locationDao: LocationDao

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        database = Room.inMemoryDatabaseBuilder(context, LocumTrackerDatabase::class.java)
            .build()
        locationDao = database.locationDao()
    }

    @After
    fun teardown() {
        database.close()
    }

    @Test
    fun testInsertAndGetLocation() = runTest {
        val location = LocationEntity(
            id = "test-1",
            name = "Test Hospital",
            address = "123 Test St",
            mmmClassification = 5,
            latitude = null,
            longitude = null,
            effectiveFrom = System.currentTimeMillis(),
            effectiveTo = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis(),
            providerNumber = null,
            phoneNumber = null,
            notes = null,
            defaultDailyRate = 1200.0,
            defaultHourlyRate = null,
            defaultOnCallRate = null,
            defaultCallOutRate = null,
            defaultSessionTemplatesJSON = null
        )

        locationDao.insertLocation(location)

        val retrieved = locationDao.getLocationById("test-1")
        assertNotNull(retrieved)
        assertEquals("Test Hospital", retrieved?.name)
        assertEquals(1200.0, retrieved?.defaultDailyRate)
    }

    @Test
    fun testGetAllLocations() = runTest {
        val location1 = createLocation("1", "Hospital 1")
        val location2 = createLocation("2", "Hospital 2")

        locationDao.insertLocation(location1)
        locationDao.insertLocation(location2)

        val locations = locationDao.getAllLocations().first()
        assertEquals(2, locations.size)
    }

    @Test
    fun testGetSubsidyEligibleLocations() = runTest {
        val location1 = createLocation("1", "Major City", mmmClassification = 1)
        val location2 = createLocation("2", "Rural Town", mmmClassification = 5)

        locationDao.insertLocation(location1)
        locationDao.insertLocation(location2)

        val eligibleLocations = locationDao.getSubsidyEligibleLocations().first()
        assertEquals(1, eligibleLocations.size)
        assertEquals("Rural Town", eligibleLocations[0].name)
    }

    @Test
    fun testUpdateLocation() = runTest {
        val location = createLocation("1", "Original Name")
        locationDao.insertLocation(location)

        val updated = location.copy(name = "Updated Name")
        locationDao.updateLocation(updated)

        val retrieved = locationDao.getLocationById("1")
        assertEquals("Updated Name", retrieved?.name)
    }

    @Test
    fun testDeleteLocation() = runTest {
        val location = createLocation("1", "To Delete")
        locationDao.insertLocation(location)

        locationDao.deleteLocation(location)

        val retrieved = locationDao.getLocationById("1")
        assertNull(retrieved)
    }

    @Test
    fun testDeleteLocationById() = runTest {
        val location = createLocation("1", "To Delete")
        locationDao.insertLocation(location)

        locationDao.deleteLocationById("1")

        val retrieved = locationDao.getLocationById("1")
        assertNull(retrieved)
    }

    @Test
    fun testGetLocationCount() = runTest {
        assertEquals(0, locationDao.getLocationCount())

        locationDao.insertLocation(createLocation("1", "Hospital 1"))
        locationDao.insertLocation(createLocation("2", "Hospital 2"))

        assertEquals(2, locationDao.getLocationCount())
    }

    private fun createLocation(
        id: String,
        name: String,
        mmmClassification: Int = 5
    ): LocationEntity {
        return LocationEntity(
            id = id,
            name = name,
            address = "123 Test St",
            mmmClassification = mmmClassification,
            latitude = null,
            longitude = null,
            effectiveFrom = System.currentTimeMillis(),
            effectiveTo = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis(),
            providerNumber = null,
            phoneNumber = null,
            notes = null,
            defaultDailyRate = null,
            defaultHourlyRate = null,
            defaultOnCallRate = null,
            defaultCallOutRate = null,
            defaultSessionTemplatesJSON = null
        )
    }
}
