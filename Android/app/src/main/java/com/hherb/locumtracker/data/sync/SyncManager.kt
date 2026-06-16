package com.hherb.locumtracker.data.sync

import com.hherb.locumtracker.data.database.entity.*
import com.hherb.locumtracker.data.repository.*
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Coordinates synchronisation of all local repositories with Firebase cloud storage.
 *
 * Aggregates the per-entity sync operations of [FirebaseSyncService] into whole-dataset
 * push ([syncToCloud]) and pull ([syncFromCloud]) operations, returning a [SyncResult].
 */
@Singleton
class SyncManager @Inject constructor(
    private val firebaseSyncService: FirebaseSyncService,
    private val locationRepository: LocationRepository,
    private val assignmentRepository: AssignmentRepository,
    private val sessionRepository: SessionRepository,
    private val receiptRepository: ReceiptRepository,
    private val profileRepository: ProfileRepository
) {
    /** Whether a user is currently signed in to Firebase. */
    val isSignedIn: Boolean
        get() = firebaseSyncService.isSignedIn

    /**
     * Signs in anonymously to Firebase.
     *
     * @return True if sign-in succeeded, false otherwise.
     */
    suspend fun signIn(): Boolean {
        return firebaseSyncService.signInAnonymously()
    }

    /** Signs the current user out of Firebase. */
    suspend fun signOut() {
        firebaseSyncService.signOut()
    }

    /**
     * Pushes all local data (locations, assignments, sessions, daily records, receipts,
     * profile, and quotas) to the cloud.
     *
     * @return A [SyncResult] describing the outcome of the operation.
     */
    suspend fun syncToCloud(): SyncResult {
        return try {
            // Get all local data
            val locations = locationRepository.getAllLocations().first()
            val assignments = assignmentRepository.getAllAssignments().first()
            val sessions = sessionRepository.getAllSessions().first()
            val dailyRecords = sessionRepository.getAllDailyRecords().first()
            val receipts = receiptRepository.getAllReceipts().first()
            val profile = profileRepository.getProfileOnce()
            val quotas = profileRepository.getAllQuotas().first()

            // Sync to Firebase
            firebaseSyncService.syncLocations(locations)

            assignments.forEach { assignment ->
                firebaseSyncService.syncAssignment(assignment)
            }

            firebaseSyncService.syncSessions(sessions)

            dailyRecords.forEach { record ->
                firebaseSyncService.syncDailyRecord(record)
            }

            receipts.forEach { receipt ->
                firebaseSyncService.syncReceipt(receipt)
            }

            if (profile != null) {
                firebaseSyncService.syncProfile(profile)
            }

            quotas.forEach { quota ->
                firebaseSyncService.syncQuota(quota)
            }

            SyncResult(
                success = true,
                message = "Synced ${locations.size} locations, ${assignments.size} assignments, ${sessions.size} sessions",
                timestamp = System.currentTimeMillis()
            )
        } catch (e: Exception) {
            SyncResult(
                success = false,
                message = "Sync failed: ${e.message}",
                timestamp = System.currentTimeMillis()
            )
        }
    }

    /**
     * Fetches all data from the cloud and inserts it into the local database, restoring
     * locations, assignments, sessions, daily records, receipts, profile, and quotas.
     *
     * @return A [SyncResult] describing the outcome of the operation.
     */
    suspend fun syncFromCloud(): SyncResult {
        return try {
            // Fetch from Firebase
            val cloudLocations = firebaseSyncService.fetchLocations()
            val cloudAssignments = firebaseSyncService.fetchAssignments()
            val cloudSessions = firebaseSyncService.fetchSessions()
            val cloudDailyRecords = firebaseSyncService.fetchDailyRecords()
            val cloudReceipts = firebaseSyncService.fetchReceipts()
            val cloudProfile = firebaseSyncService.fetchProfile()
            val cloudQuotas = firebaseSyncService.fetchQuotas()

            // Save to local database
            cloudLocations.forEach { location ->
                locationRepository.insertLocation(location)
            }

            cloudAssignments.forEach { assignment ->
                assignmentRepository.insertAssignment(assignment)
            }

            cloudSessions.forEach { session ->
                sessionRepository.insertSession(session)
            }

            cloudDailyRecords.forEach { record ->
                sessionRepository.insertDailyRecord(record)
            }

            cloudReceipts.forEach { receipt ->
                receiptRepository.insertReceipt(receipt)
            }

            if (cloudProfile != null) {
                profileRepository.insertProfile(cloudProfile)
            }

            cloudQuotas.forEach { quota ->
                profileRepository.insertQuota(quota)
            }

            SyncResult(
                success = true,
                message = "Restored ${cloudLocations.size} locations, ${cloudAssignments.size} assignments",
                timestamp = System.currentTimeMillis()
            )
        } catch (e: Exception) {
            SyncResult(
                success = false,
                message = "Restore failed: ${e.message}",
                timestamp = System.currentTimeMillis()
            )
        }
    }

    /**
     * Backs up all local data to the cloud. Alias for [syncToCloud].
     *
     * @return A [SyncResult] describing the outcome of the operation.
     */
    suspend fun backupToCloud(): SyncResult {
        return syncToCloud()
    }

    /**
     * Restores all data from the cloud into the local database. Alias for [syncFromCloud].
     *
     * @return A [SyncResult] describing the outcome of the operation.
     */
    suspend fun restoreFromCloud(): SyncResult {
        return syncFromCloud()
    }
}

/**
 * Outcome of a synchronisation operation.
 *
 * @property success Whether the operation completed successfully.
 * @property message A human-readable description of the result or error.
 * @property timestamp The epoch-millisecond time at which the result was produced.
 */
data class SyncResult(
    val success: Boolean,
    val message: String,
    val timestamp: Long
)
