package com.hherb.locumtracker.data.sync

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.hherb.locumtracker.data.database.entity.*
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Low-level Firebase access layer for syncing individual entities to and from Firestore.
 *
 * All data is stored per user under `users/{uid}/...` collections. Each entity type has
 * push (sync) and pull (fetch) operations; no-ops occur when no user is signed in.
 */
@Singleton
class FirebaseSyncService @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val auth: FirebaseAuth
) {
    /** The current Firebase user's UID, or null if no user is signed in. */
    private val userId: String?
        get() = auth.currentUser?.uid

    /** Whether a user is currently signed in to Firebase. */
    val isSignedIn: Boolean
        get() = auth.currentUser != null

    // Authentication
    /**
     * Signs in anonymously to Firebase Authentication.
     *
     * @return True if sign-in succeeded, false otherwise.
     */
    suspend fun signInAnonymously(): Boolean {
        return try {
            auth.signInAnonymously().await()
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Signs the current user out of Firebase. */
    suspend fun signOut() {
        auth.signOut()
    }

    // Location sync
    /**
     * Pushes a single location to the cloud, merging with any existing document.
     *
     * @param location The location to sync. No-op if no user is signed in.
     */
    suspend fun syncLocation(location: LocationEntity) {
        val uid = userId ?: return
        firestore.collection("users")
            .document(uid)
            .collection("locations")
            .document(location.id)
            .set(location, SetOptions.merge())
            .await()
    }

    /**
     * Pushes multiple locations to the cloud in a single batched write.
     *
     * @param locations The locations to sync. No-op if no user is signed in.
     */
    suspend fun syncLocations(locations: List<LocationEntity>) {
        val uid = userId ?: return
        val batch = firestore.batch()
        locations.forEach { location ->
            val ref = firestore.collection("users")
                .document(uid)
                .collection("locations")
                .document(location.id)
            batch.set(ref, location, SetOptions.merge())
        }
        batch.commit().await()
    }

    /**
     * Fetches all locations stored in the cloud for the current user.
     *
     * @return The list of locations, or an empty list if no user is signed in.
     */
    suspend fun fetchLocations(): List<LocationEntity> {
        val uid = userId ?: return emptyList()
        return firestore.collection("users")
            .document(uid)
            .collection("locations")
            .get()
            .await()
            .toObjects(LocationEntity::class.java)
    }

    // Assignment sync
    /**
     * Pushes a single assignment to the cloud, merging with any existing document.
     *
     * @param assignment The assignment to sync. No-op if no user is signed in.
     */
    suspend fun syncAssignment(assignment: AssignmentEntity) {
        val uid = userId ?: return
        firestore.collection("users")
            .document(uid)
            .collection("assignments")
            .document(assignment.id)
            .set(assignment, SetOptions.merge())
            .await()
    }

    /**
     * Fetches all assignments stored in the cloud for the current user.
     *
     * @return The list of assignments, or an empty list if no user is signed in.
     */
    suspend fun fetchAssignments(): List<AssignmentEntity> {
        val uid = userId ?: return emptyList()
        return firestore.collection("users")
            .document(uid)
            .collection("assignments")
            .get()
            .await()
            .toObjects(AssignmentEntity::class.java)
    }

    // Session sync
    /**
     * Pushes a single session to the cloud, merging with any existing document.
     *
     * @param session The session to sync. No-op if no user is signed in.
     */
    suspend fun syncSession(session: SessionEntity) {
        val uid = userId ?: return
        firestore.collection("users")
            .document(uid)
            .collection("sessions")
            .document(session.id)
            .set(session, SetOptions.merge())
            .await()
    }

    /**
     * Pushes multiple sessions to the cloud in a single batched write.
     *
     * @param sessions The sessions to sync. No-op if no user is signed in.
     */
    suspend fun syncSessions(sessions: List<SessionEntity>) {
        val uid = userId ?: return
        val batch = firestore.batch()
        sessions.forEach { session ->
            val ref = firestore.collection("users")
                .document(uid)
                .collection("sessions")
                .document(session.id)
            batch.set(ref, session, SetOptions.merge())
        }
        batch.commit().await()
    }

    /**
     * Fetches all sessions stored in the cloud for the current user.
     *
     * @return The list of sessions, or an empty list if no user is signed in.
     */
    suspend fun fetchSessions(): List<SessionEntity> {
        val uid = userId ?: return emptyList()
        return firestore.collection("users")
            .document(uid)
            .collection("sessions")
            .get()
            .await()
            .toObjects(SessionEntity::class.java)
    }

    // Daily Record sync
    /**
     * Pushes a single daily record to the cloud, merging with any existing document.
     *
     * @param dailyRecord The daily record to sync. No-op if no user is signed in.
     */
    suspend fun syncDailyRecord(dailyRecord: DailyRecordEntity) {
        val uid = userId ?: return
        firestore.collection("users")
            .document(uid)
            .collection("dailyRecords")
            .document(dailyRecord.id)
            .set(dailyRecord, SetOptions.merge())
            .await()
    }

    /**
     * Fetches all daily records stored in the cloud for the current user.
     *
     * @return The list of daily records, or an empty list if no user is signed in.
     */
    suspend fun fetchDailyRecords(): List<DailyRecordEntity> {
        val uid = userId ?: return emptyList()
        return firestore.collection("users")
            .document(uid)
            .collection("dailyRecords")
            .get()
            .await()
            .toObjects(DailyRecordEntity::class.java)
    }

    // Receipt sync
    /**
     * Pushes a single receipt to the cloud, merging with any existing document.
     *
     * @param receipt The receipt to sync. No-op if no user is signed in.
     */
    suspend fun syncReceipt(receipt: ReceiptEntity) {
        val uid = userId ?: return
        firestore.collection("users")
            .document(uid)
            .collection("receipts")
            .document(receipt.id)
            .set(receipt, SetOptions.merge())
            .await()
    }

    /**
     * Fetches all receipts stored in the cloud for the current user.
     *
     * @return The list of receipts, or an empty list if no user is signed in.
     */
    suspend fun fetchReceipts(): List<ReceiptEntity> {
        val uid = userId ?: return emptyList()
        return firestore.collection("users")
            .document(uid)
            .collection("receipts")
            .get()
            .await()
            .toObjects(ReceiptEntity::class.java)
    }

    // Attachment sync (metadata only, file data stored locally)
    /**
     * Pushes attachment metadata to the cloud, stripping the large local file data
     * before upload (file contents remain stored locally only).
     *
     * @param attachment The attachment whose metadata to sync. No-op if no user is signed in.
     */
    suspend fun syncAttachment(attachment: AttachmentEntity) {
        val uid = userId ?: return
        val metadata = attachment.copy(fileData = null) // Don't sync large file data
        firestore.collection("users")
            .document(uid)
            .collection("attachments")
            .document(attachment.id)
            .set(metadata, SetOptions.merge())
            .await()
    }

    /**
     * Fetches all attachment metadata stored in the cloud for the current user.
     *
     * @return The list of attachments (without file data), or an empty list if no user is signed in.
     */
    suspend fun fetchAttachments(): List<AttachmentEntity> {
        val uid = userId ?: return emptyList()
        return firestore.collection("users")
            .document(uid)
            .collection("attachments")
            .get()
            .await()
            .toObjects(AttachmentEntity::class.java)
    }

    // Profile sync
    /**
     * Pushes the locum profile to the cloud as the single "main" profile document,
     * merging with any existing document.
     *
     * @param profile The profile to sync. No-op if no user is signed in.
     */
    suspend fun syncProfile(profile: LocumProfileEntity) {
        val uid = userId ?: return
        firestore.collection("users")
            .document(uid)
            .collection("profile")
            .document("main")
            .set(profile, SetOptions.merge())
            .await()
    }

    /**
     * Fetches the locum profile ("main" document) stored in the cloud for the current user.
     *
     * @return The profile, or null if no user is signed in or no profile exists.
     */
    suspend fun fetchProfile(): LocumProfileEntity? {
        val uid = userId ?: return null
        return firestore.collection("users")
            .document(uid)
            .collection("profile")
            .document("main")
            .get()
            .await()
            .toObject(LocumProfileEntity::class.java)
    }

    // Quota sync
    /**
     * Pushes a single quarterly quota to the cloud, merging with any existing document.
     *
     * @param quota The quota to sync. No-op if no user is signed in.
     */
    suspend fun syncQuota(quota: QuarterlyQuotaEntity) {
        val uid = userId ?: return
        firestore.collection("users")
            .document(uid)
            .collection("quotas")
            .document(quota.id)
            .set(quota, SetOptions.merge())
            .await()
    }

    /**
     * Fetches all quarterly quotas stored in the cloud for the current user.
     *
     * @return The list of quotas, or an empty list if no user is signed in.
     */
    suspend fun fetchQuotas(): List<QuarterlyQuotaEntity> {
        val uid = userId ?: return emptyList()
        return firestore.collection("users")
            .document(uid)
            .collection("quotas")
            .get()
            .await()
            .toObjects(QuarterlyQuotaEntity::class.java)
    }

    // Full sync
    /**
     * Performs a full sync of the provided datasets to the cloud.
     *
     * Note: currently only locations are synced; the remaining parameters are accepted
     * for future batched syncing.
     *
     * @param locations Locations to sync.
     * @param assignments Assignments to sync (currently unused).
     * @param sessions Sessions to sync (currently unused).
     * @param dailyRecords Daily records to sync (currently unused).
     * @param receipts Receipts to sync (currently unused).
     * @param profile Profile to sync (currently unused).
     * @param quotas Quotas to sync (currently unused).
     * @return True if the sync succeeded, false if an exception occurred.
     */
    suspend fun syncAll(
        locations: List<LocationEntity>,
        assignments: List<AssignmentEntity>,
        sessions: List<SessionEntity>,
        dailyRecords: List<DailyRecordEntity>,
        receipts: List<ReceiptEntity>,
        profile: LocumProfileEntity?,
        quotas: List<QuarterlyQuotaEntity>
    ): Boolean {
        return try {
            syncLocations(locations)
            // Note: In production, you'd batch these for efficiency
            true
        } catch (e: Exception) {
            false
        }
    }
}
