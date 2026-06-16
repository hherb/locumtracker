package com.hherb.locumtracker.data.database

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hherb.locumtracker.data.database.dao.SessionDao
import com.hherb.locumtracker.data.database.entity.DailyRecordEntity
import com.hherb.locumtracker.data.database.entity.SessionEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SessionDaoTest {

    private lateinit var database: LocumTrackerDatabase
    private lateinit var sessionDao: SessionDao

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        database = Room.inMemoryDatabaseBuilder(context, LocumTrackerDatabase::class.java)
            .build()
        sessionDao = database.sessionDao()
    }

    @After
    fun teardown() {
        database.close()
    }

    @Test
    fun testInsertAndGetSession() = runTest {
        val dailyRecord = createDailyRecord("record-1")
        sessionDao.insertDailyRecord(dailyRecord)

        val session = SessionEntity(
            id = "session-1",
            dailyRecordId = "record-1",
            startTime = System.currentTimeMillis(),
            endTime = System.currentTimeMillis() + 4 * 60 * 60 * 1000L, // 4 hours
            sessionType = "regular",
            mmmClassification = 5,
            travelTime = null,
            subsidyAmount = null,
            notes = "Test session",
            locationId = null,
            providerLocationId = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )

        sessionDao.insertSession(session)

        val retrieved = sessionDao.getSessionById("session-1")
        assertNotNull(retrieved)
        assertEquals("regular", retrieved?.sessionType)
        assertEquals("Test session", retrieved?.notes)
    }

    @Test
    fun testGetSessionsForDailyRecord() = runTest {
        val dailyRecord = createDailyRecord("record-1")
        sessionDao.insertDailyRecord(dailyRecord)

        val session1 = createSession("session-1", "record-1")
        val session2 = createSession("session-2", "record-1")
        val session3 = createSession("session-3", "record-2")

        sessionDao.insertSession(session1)
        sessionDao.insertSession(session2)
        sessionDao.insertSession(session3)

        val sessions = sessionDao.getSessionsForDailyRecord("record-1").first()
        assertEquals(2, sessions.size)
    }

    @Test
    fun testGetSessionsForAssignment() = runTest {
        val dailyRecord1 = createDailyRecord("record-1", assignmentId = "assign-1")
        val dailyRecord2 = createDailyRecord("record-2", assignmentId = "assign-2")

        sessionDao.insertDailyRecord(dailyRecord1)
        sessionDao.insertDailyRecord(dailyRecord2)

        val session1 = createSession("session-1", "record-1")
        val session2 = createSession("session-2", "record-2")

        sessionDao.insertSession(session1)
        sessionDao.insertSession(session2)

        val sessions = sessionDao.getSessionsForAssignment("assign-1").first()
        assertEquals(1, sessions.size)
        assertEquals("session-1", sessions[0].id)
    }

    @Test
    fun testUpdateSession() = runTest {
        val dailyRecord = createDailyRecord("record-1")
        sessionDao.insertDailyRecord(dailyRecord)

        val session = createSession("session-1", "record-1")
        sessionDao.insertSession(session)

        val updated = session.copy(notes = "Updated notes", sessionType = "on_call")
        sessionDao.updateSession(updated)

        val retrieved = sessionDao.getSessionById("session-1")
        assertEquals("Updated notes", retrieved?.notes)
        assertEquals("on_call", retrieved?.sessionType)
    }

    @Test
    fun testDeleteSession() = runTest {
        val dailyRecord = createDailyRecord("record-1")
        sessionDao.insertDailyRecord(dailyRecord)

        val session = createSession("session-1", "record-1")
        sessionDao.insertSession(session)

        sessionDao.deleteSession(session)

        val retrieved = sessionDao.getSessionById("session-1")
        assertNull(retrieved)
    }

    @Test
    fun testInsertAndGetDailyRecord() = runTest {
        val dailyRecord = DailyRecordEntity(
            id = "record-1",
            assignmentId = "assign-1",
            date = System.currentTimeMillis(),
            isOnCall = false,
            totalEarnings = 1200.0,
            notes = "Test day",
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )

        sessionDao.insertDailyRecord(dailyRecord)

        val retrieved = sessionDao.getDailyRecordById("record-1")
        assertNotNull(retrieved)
        assertEquals(1200.0, retrieved?.totalEarnings)
        assertEquals("Test day", retrieved?.notes)
    }

    @Test
    fun testGetDailyRecordsForAssignment() = runTest {
        val record1 = createDailyRecord("record-1", assignmentId = "assign-1")
        val record2 = createDailyRecord("record-2", assignmentId = "assign-1")
        val record3 = createDailyRecord("record-3", assignmentId = "assign-2")

        sessionDao.insertDailyRecord(record1)
        sessionDao.insertDailyRecord(record2)
        sessionDao.insertDailyRecord(record3)

        val records = sessionDao.getDailyRecordsForAssignment("assign-1").first()
        assertEquals(2, records.size)
    }

    @Test
    fun testGetOrCreateDailyRecord_existing() = runTest {
        val record = createDailyRecord("record-1", assignmentId = "assign-1", date = 1000000L)
        sessionDao.insertDailyRecord(record)

        val retrieved = sessionDao.getDailyRecordForAssignmentAndDate("assign-1", 1000000L)
        assertNotNull(retrieved)
        assertEquals("record-1", retrieved?.id)
    }

    @Test
    fun testDeleteSessionsForDailyRecord() = runTest {
        val dailyRecord = createDailyRecord("record-1")
        sessionDao.insertDailyRecord(dailyRecord)

        val session1 = createSession("session-1", "record-1")
        val session2 = createSession("session-2", "record-1")

        sessionDao.insertSession(session1)
        sessionDao.insertSession(session2)

        sessionDao.deleteSessionsForDailyRecord("record-1")

        val sessions = sessionDao.getSessionsForDailyRecord("record-1").first()
        assertTrue(sessions.isEmpty())
    }

    private fun createDailyRecord(
        id: String,
        assignmentId: String = "assign-1",
        date: Long = System.currentTimeMillis()
    ): DailyRecordEntity {
        return DailyRecordEntity(
            id = id,
            assignmentId = assignmentId,
            date = date,
            isOnCall = false,
            totalEarnings = 0.0,
            notes = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
    }

    private fun createSession(
        id: String,
        dailyRecordId: String
    ): SessionEntity {
        return SessionEntity(
            id = id,
            dailyRecordId = dailyRecordId,
            startTime = System.currentTimeMillis(),
            endTime = System.currentTimeMillis() + 4 * 60 * 60 * 1000L,
            sessionType = "regular",
            mmmClassification = 5,
            travelTime = null,
            subsidyAmount = null,
            notes = null,
            locationId = null,
            providerLocationId = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
    }
}
