package com.hherb.locumtracker.data.database

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hherb.locumtracker.data.database.dao.ProfileDao
import com.hherb.locumtracker.data.database.entity.LocumProfileEntity
import com.hherb.locumtracker.data.database.entity.QuarterlyQuotaEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ProfileDaoTest {

    private lateinit var database: LocumTrackerDatabase
    private lateinit var profileDao: ProfileDao

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        database = Room.inMemoryDatabaseBuilder(context, LocumTrackerDatabase::class.java)
            .build()
        profileDao = database.profileDao()
    }

    @After
    fun teardown() {
        database.close()
    }

    @Test
    fun testInsertAndGetProfile() = runTest {
        val profile = LocumProfileEntity(
            id = "profile-1",
            title = "Dr",
            firstName = "John",
            lastName = "Smith",
            email = "john@example.com",
            streetAddress = "123 Main St",
            suburb = "Sydney",
            state = "NSW",
            postcode = "2000",
            businessStructure = "Sole Trader",
            abn = "12345678901",
            isGstRegistered = true,
            isVocationalRegister = true,
            providerNumber = "12345",
            specialty = "Emergency Medicine",
            defaultDailyRate = 1500.0,
            defaultHourlyRate = null,
            defaultOnCallRate = null,
            defaultCallOutRate = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )

        profileDao.insertProfile(profile)

        val retrieved = profileDao.getProfileOnce()
        assertNotNull(retrieved)
        assertEquals("John", retrieved?.firstName)
        assertEquals("Smith", retrieved?.lastName)
        assertEquals("12345678901", retrieved?.abn)
    }

    @Test
    fun testUpdateProfile() = runTest {
        val profile = createProfile("profile-1", "John")
        profileDao.insertProfile(profile)

        val updated = profile.copy(firstName = "Jane")
        profileDao.updateProfile(updated)

        val retrieved = profileDao.getProfileOnce()
        assertEquals("Jane", retrieved?.firstName)
    }

    @Test
    fun testDeleteProfile() = runTest {
        val profile = createProfile("profile-1", "John")
        profileDao.insertProfile(profile)

        profileDao.deleteProfile()

        val retrieved = profileDao.getProfileOnce()
        assertNull(retrieved)
    }

    @Test
    fun testInsertAndGetQuota() = runTest {
        val quota = QuarterlyQuotaEntity(
            id = "quota-1",
            practitionerId = "practitioner-1",
            quarterStartDate = System.currentTimeMillis(),
            mmm3Sessions = 5,
            mmm4Sessions = 3,
            mmm5Sessions = 2,
            mmm6Sessions = 0,
            mmm7Sessions = 0,
            totalSessions = 10,
            quotaMet = false,
            lastUpdated = System.currentTimeMillis()
        )

        profileDao.insertQuota(quota)

        val retrieved = profileDao.getQuotaById("quota-1")
        assertNotNull(retrieved)
        assertEquals(10, retrieved?.totalSessions)
        assertEquals(5, retrieved?.mmm3Sessions)
    }

    @Test
    fun testGetQuotasForPractitioner() = runTest {
        val quota1 = createQuota("quota-1", "practitioner-1")
        val quota2 = createQuota("quota-2", "practitioner-1")
        val quota3 = createQuota("quota-3", "practitioner-2")

        profileDao.insertQuota(quota1)
        profileDao.insertQuota(quota2)
        profileDao.insertQuota(quota3)

        val quotas = profileDao.getQuotasForPractitioner("practitioner-1").first()
        assertEquals(2, quotas.size)
    }

    @Test
    fun testUpdateQuota() = runTest {
        val quota = createQuota("quota-1", "practitioner-1")
        profileDao.insertQuota(quota)

        val updated = quota.copy(totalSessions = 25, quotaMet = true)
        profileDao.updateQuota(updated)

        val retrieved = profileDao.getQuotaById("quota-1")
        assertEquals(25, retrieved?.totalSessions)
        assertTrue(retrieved?.quotaMet == true)
    }

    @Test
    fun testDeleteQuota() = runTest {
        val quota = createQuota("quota-1", "practitioner-1")
        profileDao.insertQuota(quota)

        profileDao.deleteQuota(quota)

        val retrieved = profileDao.getQuotaById("quota-1")
        assertNull(retrieved)
    }

    @Test
    fun testGetCurrentQuota() = runTest {
        val quota = createQuota("quota-1", "practitioner-1")
        profileDao.insertQuota(quota)

        val current = profileDao.getCurrentQuota("practitioner-1", System.currentTimeMillis())
        assertNotNull(current)
        assertEquals("quota-1", current?.id)
    }

    private fun createProfile(
        id: String,
        firstName: String
    ): LocumProfileEntity {
        return LocumProfileEntity(
            id = id,
            title = null,
            firstName = firstName,
            lastName = "Smith",
            email = null,
            streetAddress = null,
            suburb = null,
            state = null,
            postcode = null,
            businessStructure = null,
            abn = null,
            isGstRegistered = false,
            isVocationalRegister = false,
            providerNumber = null,
            specialty = null,
            defaultDailyRate = null,
            defaultHourlyRate = null,
            defaultOnCallRate = null,
            defaultCallOutRate = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
    }

    private fun createQuota(
        id: String,
        practitionerId: String
    ): QuarterlyQuotaEntity {
        return QuarterlyQuotaEntity(
            id = id,
            practitionerId = practitionerId,
            quarterStartDate = System.currentTimeMillis(),
            mmm3Sessions = 0,
            mmm4Sessions = 0,
            mmm5Sessions = 0,
            mmm6Sessions = 0,
            mmm7Sessions = 0,
            totalSessions = 0,
            quotaMet = false,
            lastUpdated = System.currentTimeMillis()
        )
    }
}
