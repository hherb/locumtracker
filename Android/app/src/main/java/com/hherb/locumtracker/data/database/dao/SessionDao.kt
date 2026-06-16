package com.hherb.locumtracker.data.database.dao

import androidx.room.*
import com.hherb.locumtracker.data.database.entity.DailyRecordEntity
import com.hherb.locumtracker.data.database.entity.SessionEntity
import kotlinx.coroutines.flow.Flow

/** Room data-access object for [SessionEntity] and [DailyRecordEntity] rows. */
@Dao
interface SessionDao {
    // Session queries
    /** Observes all sessions, newest start time first. */
    @Query("SELECT * FROM sessions ORDER BY startTime DESC")
    fun getAllSessions(): Flow<List<SessionEntity>>

    /** Observes the sessions belonging to [dailyRecordId], earliest start time first. */
    @Query("SELECT * FROM sessions WHERE dailyRecordId = :dailyRecordId ORDER BY startTime ASC")
    fun getSessionsForDailyRecord(dailyRecordId: String): Flow<List<SessionEntity>>

    /** Returns the session with the given [id], or `null` if none exists. */
    @Query("SELECT * FROM sessions WHERE id = :id")
    suspend fun getSessionById(id: String): SessionEntity?

    /** Observes the session with the given [id], emitting `null` if absent. */
    @Query("SELECT * FROM sessions WHERE id = :id")
    fun getSessionByIdFlow(id: String): Flow<SessionEntity?>

    /** Observes all sessions under [assignmentId] (joined via daily records), newest first. */
    @Query("""
        SELECT s.* FROM sessions s
        INNER JOIN daily_records d ON s.dailyRecordId = d.id
        WHERE d.assignmentId = :assignmentId
        ORDER BY s.startTime DESC
    """)
    fun getSessionsForAssignment(assignmentId: String): Flow<List<SessionEntity>>

    /**
     * Observes sessions under [assignmentId] with a start time within
     * [startTime]..[endTime] inclusive, earliest first.
     */
    @Query("""
        SELECT s.* FROM sessions s
        INNER JOIN daily_records d ON s.dailyRecordId = d.id
        WHERE d.assignmentId = :assignmentId AND s.startTime >= :startTime AND s.startTime <= :endTime
        ORDER BY s.startTime ASC
    """)
    fun getSessionsForAssignmentInDateRange(
        assignmentId: String,
        startTime: Long,
        endTime: Long
    ): Flow<List<SessionEntity>>

    /** Inserts [session], replacing any existing row with the same primary key. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: SessionEntity)

    /** Updates the stored row matching [session]. */
    @Update
    suspend fun updateSession(session: SessionEntity)

    /** Deletes the row matching [session]. */
    @Delete
    suspend fun deleteSession(session: SessionEntity)

    /** Deletes the session with the given [id]. */
    @Query("DELETE FROM sessions WHERE id = :id")
    suspend fun deleteSessionById(id: String)

    /** Deletes all sessions belonging to [dailyRecordId]. */
    @Query("DELETE FROM sessions WHERE dailyRecordId = :dailyRecordId")
    suspend fun deleteSessionsForDailyRecord(dailyRecordId: String)

    // Daily Record queries
    /** Observes all daily records, newest date first. */
    @Query("SELECT * FROM daily_records ORDER BY date DESC")
    fun getAllDailyRecords(): Flow<List<DailyRecordEntity>>

    /** Observes the daily records for [assignmentId], newest date first. */
    @Query("SELECT * FROM daily_records WHERE assignmentId = :assignmentId ORDER BY date DESC")
    fun getDailyRecordsForAssignment(assignmentId: String): Flow<List<DailyRecordEntity>>

    /** Returns the daily record with the given [id], or `null` if none exists. */
    @Query("SELECT * FROM daily_records WHERE id = :id")
    suspend fun getDailyRecordById(id: String): DailyRecordEntity?

    /** Observes the daily record with the given [id], emitting `null` if absent. */
    @Query("SELECT * FROM daily_records WHERE id = :id")
    fun getDailyRecordByIdFlow(id: String): Flow<DailyRecordEntity?>

    /** Returns the daily record for [assignmentId] on [date], or `null` if none exists. */
    @Query("SELECT * FROM daily_records WHERE assignmentId = :assignmentId AND date = :date")
    suspend fun getDailyRecordForAssignmentAndDate(assignmentId: String, date: Long): DailyRecordEntity?

    /** Inserts [dailyRecord], replacing any existing row with the same primary key. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDailyRecord(dailyRecord: DailyRecordEntity)

    /** Updates the stored row matching [dailyRecord]. */
    @Update
    suspend fun updateDailyRecord(dailyRecord: DailyRecordEntity)

    /** Deletes the row matching [dailyRecord]. */
    @Delete
    suspend fun deleteDailyRecord(dailyRecord: DailyRecordEntity)

    /** Deletes the daily record with the given [id]. */
    @Query("DELETE FROM daily_records WHERE id = :id")
    suspend fun deleteDailyRecordById(id: String)

    /** Deletes all daily records belonging to [assignmentId]. */
    @Query("DELETE FROM daily_records WHERE assignmentId = :assignmentId")
    suspend fun deleteDailyRecordsForAssignment(assignmentId: String)
}
