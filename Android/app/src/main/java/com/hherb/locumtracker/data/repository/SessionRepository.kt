package com.hherb.locumtracker.data.repository

import com.hherb.locumtracker.data.database.dao.SessionDao
import com.hherb.locumtracker.data.database.entity.DailyRecordEntity
import com.hherb.locumtracker.data.database.entity.SessionEntity
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository providing access to sessions and their parent daily records.
 *
 * Wraps [SessionDao] to expose session and daily-record persistence operations,
 * including a helper to look up or lazily create a daily record for a given date.
 */
@Singleton
class SessionRepository @Inject constructor(
    private val sessionDao: SessionDao
) {
    // Session operations
    /** Returns a stream of all sessions. */
    fun getAllSessions(): Flow<List<SessionEntity>> = sessionDao.getAllSessions()

    /**
     * Returns a stream of sessions belonging to the given daily record.
     *
     * @param dailyRecordId Identifier of the daily record.
     */
    fun getSessionsForDailyRecord(dailyRecordId: String): Flow<List<SessionEntity>> = sessionDao.getSessionsForDailyRecord(dailyRecordId)

    /**
     * Fetches a single session by its identifier.
     *
     * @param id Identifier of the session.
     * @return The matching session, or null if none exists.
     */
    suspend fun getSessionById(id: String): SessionEntity? = sessionDao.getSessionById(id)

    /**
     * Returns a stream emitting the session with the given identifier as it changes.
     *
     * @param id Identifier of the session.
     */
    fun getSessionByIdFlow(id: String): Flow<SessionEntity?> = sessionDao.getSessionByIdFlow(id)

    /**
     * Returns a stream of sessions belonging to the given assignment.
     *
     * @param assignmentId Identifier of the assignment.
     */
    fun getSessionsForAssignment(assignmentId: String): Flow<List<SessionEntity>> = sessionDao.getSessionsForAssignment(assignmentId)

    /**
     * Returns a stream of sessions for an assignment that fall within a time range.
     *
     * @param assignmentId Identifier of the assignment.
     * @param startTime Inclusive start of the range as epoch milliseconds.
     * @param endTime Inclusive end of the range as epoch milliseconds.
     */
    fun getSessionsForAssignmentInDateRange(
        assignmentId: String,
        startTime: Long,
        endTime: Long
    ): Flow<List<SessionEntity>> = sessionDao.getSessionsForAssignmentInDateRange(assignmentId, startTime, endTime)

    /** Inserts a session. */
    suspend fun insertSession(session: SessionEntity) = sessionDao.insertSession(session)

    /** Updates an existing session. */
    suspend fun updateSession(session: SessionEntity) = sessionDao.updateSession(session)

    /** Deletes a session. */
    suspend fun deleteSession(session: SessionEntity) = sessionDao.deleteSession(session)

    /** Deletes a session by its identifier. */
    suspend fun deleteSessionById(id: String) = sessionDao.deleteSessionById(id)

    // Daily Record operations
    /** Returns a stream of all daily records. */
    fun getAllDailyRecords(): Flow<List<DailyRecordEntity>> = sessionDao.getAllDailyRecords()

    /**
     * Returns a stream of daily records belonging to the given assignment.
     *
     * @param assignmentId Identifier of the assignment.
     */
    fun getDailyRecordsForAssignment(assignmentId: String): Flow<List<DailyRecordEntity>> = sessionDao.getDailyRecordsForAssignment(assignmentId)

    /**
     * Fetches a single daily record by its identifier.
     *
     * @param id Identifier of the daily record.
     * @return The matching daily record, or null if none exists.
     */
    suspend fun getDailyRecordById(id: String): DailyRecordEntity? = sessionDao.getDailyRecordById(id)

    /**
     * Returns a stream emitting the daily record with the given identifier as it changes.
     *
     * @param id Identifier of the daily record.
     */
    fun getDailyRecordByIdFlow(id: String): Flow<DailyRecordEntity?> = sessionDao.getDailyRecordByIdFlow(id)

    /**
     * Fetches the daily record for an assignment on a specific date.
     *
     * @param assignmentId Identifier of the assignment.
     * @param date Date as epoch milliseconds.
     * @return The matching daily record, or null if none exists.
     */
    suspend fun getDailyRecordForAssignmentAndDate(assignmentId: String, date: Long): DailyRecordEntity? =
        sessionDao.getDailyRecordForAssignmentAndDate(assignmentId, date)

    /** Inserts a daily record. */
    suspend fun insertDailyRecord(dailyRecord: DailyRecordEntity) = sessionDao.insertDailyRecord(dailyRecord)

    /** Updates an existing daily record. */
    suspend fun updateDailyRecord(dailyRecord: DailyRecordEntity) = sessionDao.updateDailyRecord(dailyRecord)

    /** Deletes a daily record. */
    suspend fun deleteDailyRecord(dailyRecord: DailyRecordEntity) = sessionDao.deleteDailyRecord(dailyRecord)

    /** Deletes a daily record by its identifier. */
    suspend fun deleteDailyRecordById(id: String) = sessionDao.deleteDailyRecordById(id)

    /**
     * Returns the existing daily record for an assignment on the given date, or creates,
     * persists and returns a new empty one if none exists yet.
     *
     * @param assignmentId Identifier of the assignment.
     * @param date Date as epoch milliseconds.
     * @return The existing or newly created daily record.
     */
    suspend fun getOrCreateDailyRecord(assignmentId: String, date: Long): DailyRecordEntity {
        val existing = sessionDao.getDailyRecordForAssignmentAndDate(assignmentId, date)
        if (existing != null) return existing

        val newRecord = DailyRecordEntity(
            id = java.util.UUID.randomUUID().toString(),
            assignmentId = assignmentId,
            date = date,
            isOnCall = false,
            totalEarnings = 0.0,
            notes = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        sessionDao.insertDailyRecord(newRecord)
        return newRecord
    }
}
