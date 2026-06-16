package com.hherb.locumtracker.data.repository

import com.hherb.locumtracker.data.database.dao.AssignmentDao
import com.hherb.locumtracker.data.database.dao.SessionDao
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository providing access to assignments.
 *
 * Wraps [AssignmentDao] for assignment persistence and uses [SessionDao] to remove
 * dependent daily records when an assignment is deleted.
 */
@Singleton
class AssignmentRepository @Inject constructor(
    private val assignmentDao: AssignmentDao,
    private val sessionDao: SessionDao
) {
    /** Returns a stream of all assignments. */
    fun getAllAssignments(): Flow<List<AssignmentEntity>> = assignmentDao.getAllAssignments()

    /**
     * Returns a stream of assignments with the given status.
     *
     * @param status Assignment status to filter by.
     */
    fun getAssignmentsByStatus(status: String): Flow<List<AssignmentEntity>> = assignmentDao.getAssignmentsByStatus(status)

    /**
     * Fetches a single assignment by its identifier.
     *
     * @param id Identifier of the assignment.
     * @return The matching assignment, or null if none exists.
     */
    suspend fun getAssignmentById(id: String): AssignmentEntity? = assignmentDao.getAssignmentById(id)

    /**
     * Returns a stream emitting the assignment with the given identifier as it changes.
     *
     * @param id Identifier of the assignment.
     */
    fun getAssignmentByIdFlow(id: String): Flow<AssignmentEntity?> = assignmentDao.getAssignmentByIdFlow(id)

    /**
     * Returns a stream of assignments at the given location.
     *
     * @param locationId Identifier of the location.
     */
    fun getAssignmentsByLocation(locationId: String): Flow<List<AssignmentEntity>> = assignmentDao.getAssignmentsByLocation(locationId)

    /**
     * Returns a stream of assignments active on the given date.
     *
     * @param date Date as epoch milliseconds.
     */
    fun getActiveAssignmentsAtDate(date: Long): Flow<List<AssignmentEntity>> = assignmentDao.getActiveAssignmentsAtDate(date)

    /** Inserts an assignment. */
    suspend fun insertAssignment(assignment: AssignmentEntity) = assignmentDao.insertAssignment(assignment)

    /** Updates an existing assignment. */
    suspend fun updateAssignment(assignment: AssignmentEntity) = assignmentDao.updateAssignment(assignment)

    /**
     * Deletes an assignment along with its dependent daily records, removing the daily
     * records first so no orphans remain.
     *
     * @param assignment The assignment to delete.
     */
    suspend fun deleteAssignment(assignment: AssignmentEntity) {
        // Remove dependent daily records first so no orphans remain, then the assignment itself.
        sessionDao.deleteDailyRecordsForAssignment(assignment.id)
        assignmentDao.deleteAssignment(assignment)
    }

    /**
     * Deletes an assignment and its dependent daily records by identifier, removing the
     * daily records first so no orphans remain.
     *
     * @param id Identifier of the assignment to delete.
     */
    suspend fun deleteAssignmentById(id: String) {
        sessionDao.deleteDailyRecordsForAssignment(id)
        assignmentDao.deleteAssignmentById(id)
    }

    /** Returns the total number of assignments. */
    suspend fun getAssignmentCount(): Int = assignmentDao.getAssignmentCount()
}
