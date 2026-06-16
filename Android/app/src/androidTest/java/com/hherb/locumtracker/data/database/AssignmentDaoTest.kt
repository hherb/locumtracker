package com.hherb.locumtracker.data.database

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hherb.locumtracker.data.database.dao.AssignmentDao
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AssignmentDaoTest {

    private lateinit var database: LocumTrackerDatabase
    private lateinit var assignmentDao: AssignmentDao

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        database = Room.inMemoryDatabaseBuilder(context, LocumTrackerDatabase::class.java)
            .build()
        assignmentDao = database.assignmentDao()
    }

    @After
    fun teardown() {
        database.close()
    }

    @Test
    fun testInsertAndGetAssignment() = runTest {
        val assignment = AssignmentEntity(
            id = "test-1",
            locationId = "loc-1",
            rateStructure = "hourly_rate",
            hourlyRate = 150.0,
            dailyRate = null,
            onCallRate = 37.50,
            callOutRate = null,
            startDate = System.currentTimeMillis(),
            endDate = System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000L,
            status = "active",
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis(),
            name = "Test Assignment",
            mainProviderNumber = "12345",
            defaultSessionTemplatesJSON = null,
            additionalLocationIdsJSON = null,
            providerLocationsJSON = null
        )

        assignmentDao.insertAssignment(assignment)

        val retrieved = assignmentDao.getAssignmentById("test-1")
        assertNotNull(retrieved)
        assertEquals("Test Assignment", retrieved?.name)
        assertEquals(150.0, retrieved?.hourlyRate)
    }

    @Test
    fun testGetAllAssignments() = runTest {
        val assignment1 = createAssignment("1", "Assignment 1")
        val assignment2 = createAssignment("2", "Assignment 2")

        assignmentDao.insertAssignment(assignment1)
        assignmentDao.insertAssignment(assignment2)

        val assignments = assignmentDao.getAllAssignments().first()
        assertEquals(2, assignments.size)
    }

    @Test
    fun testGetAssignmentsByStatus() = runTest {
        val assignment1 = createAssignment("1", "Active", status = "active")
        val assignment2 = createAssignment("2", "Planned", status = "planned")
        val assignment3 = createAssignment("3", "Active 2", status = "active")

        assignmentDao.insertAssignment(assignment1)
        assignmentDao.insertAssignment(assignment2)
        assignmentDao.insertAssignment(assignment3)

        val activeAssignments = assignmentDao.getAssignmentsByStatus("active").first()
        assertEquals(2, activeAssignments.size)
    }

    @Test
    fun testUpdateAssignment() = runTest {
        val assignment = createAssignment("1", "Original")
        assignmentDao.insertAssignment(assignment)

        val updated = assignment.copy(name = "Updated", status = "completed")
        assignmentDao.updateAssignment(updated)

        val retrieved = assignmentDao.getAssignmentById("1")
        assertEquals("Updated", retrieved?.name)
        assertEquals("completed", retrieved?.status)
    }

    @Test
    fun testDeleteAssignment() = runTest {
        val assignment = createAssignment("1", "To Delete")
        assignmentDao.insertAssignment(assignment)

        assignmentDao.deleteAssignment(assignment)

        val retrieved = assignmentDao.getAssignmentById("1")
        assertNull(retrieved)
    }

    @Test
    fun testGetAssignmentCount() = runTest {
        assertEquals(0, assignmentDao.getAssignmentCount())

        assignmentDao.insertAssignment(createAssignment("1", "Assignment 1"))
        assignmentDao.insertAssignment(createAssignment("2", "Assignment 2"))

        assertEquals(2, assignmentDao.getAssignmentCount())
    }

    @Test
    fun testGetAssignmentsByLocation() = runTest {
        val assignment1 = createAssignment("1", "Assignment 1", locationId = "loc-1")
        val assignment2 = createAssignment("2", "Assignment 2", locationId = "loc-2")
        val assignment3 = createAssignment("3", "Assignment 3", locationId = "loc-1")

        assignmentDao.insertAssignment(assignment1)
        assignmentDao.insertAssignment(assignment2)
        assignmentDao.insertAssignment(assignment3)

        val assignments = assignmentDao.getAssignmentsByLocation("loc-1").first()
        assertEquals(2, assignments.size)
    }

    private fun createAssignment(
        id: String,
        name: String,
        locationId: String = "loc-1",
        status: String = "planned"
    ): AssignmentEntity {
        return AssignmentEntity(
            id = id,
            locationId = locationId,
            rateStructure = "hourly_rate",
            hourlyRate = 150.0,
            dailyRate = null,
            onCallRate = null,
            callOutRate = null,
            startDate = System.currentTimeMillis(),
            endDate = System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000L,
            status = status,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis(),
            name = name,
            mainProviderNumber = null,
            defaultSessionTemplatesJSON = null,
            additionalLocationIdsJSON = null,
            providerLocationsJSON = null
        )
    }
}
