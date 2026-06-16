package com.hherb.locumtracker.data.database.dao

import androidx.room.*
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import kotlinx.coroutines.flow.Flow

/** Room data-access object for [AssignmentEntity] rows. */
@Dao
interface AssignmentDao {
    /** Observes all assignments, newest start date first. */
    @Query("SELECT * FROM assignments ORDER BY startDate DESC")
    fun getAllAssignments(): Flow<List<AssignmentEntity>>

    /** Observes assignments with the given [status], newest start date first. */
    @Query("SELECT * FROM assignments WHERE status = :status ORDER BY startDate DESC")
    fun getAssignmentsByStatus(status: String): Flow<List<AssignmentEntity>>

    /** Returns the assignment with the given [id], or `null` if none exists. */
    @Query("SELECT * FROM assignments WHERE id = :id")
    suspend fun getAssignmentById(id: String): AssignmentEntity?

    /** Observes the assignment with the given [id], emitting `null` if absent. */
    @Query("SELECT * FROM assignments WHERE id = :id")
    fun getAssignmentByIdFlow(id: String): Flow<AssignmentEntity?>

    /** Observes assignments at the given [locationId], newest start date first. */
    @Query("SELECT * FROM assignments WHERE locationId = :locationId ORDER BY startDate DESC")
    fun getAssignmentsByLocation(locationId: String): Flow<List<AssignmentEntity>>

    /** Observes assignments whose date range contains the given [date]. */
    @Query("SELECT * FROM assignments WHERE startDate <= :date AND endDate >= :date")
    fun getActiveAssignmentsAtDate(date: Long): Flow<List<AssignmentEntity>>

    /** Inserts [assignment], replacing any existing row with the same primary key. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAssignment(assignment: AssignmentEntity)

    /** Updates the stored row matching [assignment]. */
    @Update
    suspend fun updateAssignment(assignment: AssignmentEntity)

    /** Deletes the row matching [assignment]. */
    @Delete
    suspend fun deleteAssignment(assignment: AssignmentEntity)

    /** Deletes the assignment with the given [id]. */
    @Query("DELETE FROM assignments WHERE id = :id")
    suspend fun deleteAssignmentById(id: String)

    /** Returns the total number of assignments. */
    @Query("SELECT COUNT(*) FROM assignments")
    suspend fun getAssignmentCount(): Int
}
